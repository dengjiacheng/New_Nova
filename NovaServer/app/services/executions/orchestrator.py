"""执行域用例服务。"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional, Protocol
import sys

from fastapi import HTTPException, status

from app.repositories.executions import (
    ExecutionRecord,
    ExecutionRepository,
    ExecutionStatus,
    generate_execution_id,
)
from app.repositories.scripts import ScriptRecord
from app.schemas.executions import (
    ExecutionCreateRequest,
    ExecutionCreateResponse,
    ExecutionItemResponse,
    ExecutionListFilters,
    ExecutionListResponse,
    ExecutionRecordResponse,
)
from app.services.billing import BillingLedger, InsufficientBalance
from app.services.executions_dispatcher import DispatchTask, ExecutionDispatcher
from app.services.pubsub import PubSubBus
from app.services.scripts import ScriptService


class BillingGateway(Protocol):
    """账务接口抽象，便于替换实现。"""

    def deduct(self, tenant_id: str, amount: Decimal) -> Decimal: ...


class DispatchGateway(Protocol):
    """执行派发接口抽象。"""

    def enqueue(self, device_key: str, task: DispatchTask) -> None: ...


class EventPublisher(Protocol):
    """事件发布接口抽象。"""

    async def publish_execution_queued(self, tenant_id: str, payload: dict) -> None: ...


# Python 3.10+ supports dataclass slots; gracefully degrade for lower versions
_EXECUTION_CONTEXT_DATACLASS_KWARGS = {"slots": True} if sys.version_info >= (3, 10) else {}


@dataclass(**_EXECUTION_CONTEXT_DATACLASS_KWARGS)
class ExecutionContext:
    """执行创建时的上下文信息。"""

    tenant_id: str
    user_id: str
    pc_id: str


class ExecutionValidator:
    """负责脚本存在性、版本与授权校验。"""

    def __init__(self, script_service: ScriptService) -> None:
        self._scripts = script_service

    async def ensure_valid(
        self,
        tenant_id: str,
        request_item,
    ) -> ScriptRecord:
        script = await self._scripts.get_script(request_item.script_id)
        if not script:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="SCRIPT_NOT_FOUND",
            )

        if script.version != request_item.script_version:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="SCRIPT_VERSION_MISMATCH",
            )

        if not await self._scripts.has_purchase(tenant_id, script.id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="SCRIPT_NOT_PURCHASED",
            )

        return script


class LedgerBillingGateway:
    """基于内存账本的账务适配器。"""

    def __init__(self, ledger: BillingLedger) -> None:
        self._ledger = ledger

    def deduct(self, tenant_id: str, amount: Decimal) -> Decimal:
        return self._ledger.deduct(tenant_id, amount)


class DispatcherGateway:
    """封装执行派发实现。"""

    def __init__(self, dispatcher: ExecutionDispatcher) -> None:
        self._dispatcher = dispatcher

    def enqueue(self, device_key: str, task: DispatchTask) -> None:
        self._dispatcher.enqueue(device_key, task)


class TenantEventPublisher:
    """通过 PubSubBus 发布执行事件。"""

    def __init__(self, bus: PubSubBus) -> None:
        self._bus = bus

    async def publish_execution_queued(self, tenant_id: str, payload: dict) -> None:
        await self._bus.publish(f"tenant:{tenant_id}", payload)


class ExecutionService:
    """执行任务主用例，负责创建与查询流程。"""

    def __init__(
        self,
        repository: ExecutionRepository,
        script_service: ScriptService,
        billing: BillingGateway,
        dispatcher: DispatchGateway,
        publisher: EventPublisher,
        validator: Optional[ExecutionValidator] = None,
    ) -> None:
        self._repository = repository
        self._scripts = script_service
        self._billing = billing
        self._dispatcher = dispatcher
        self._publisher = publisher
        self._validator = validator or ExecutionValidator(script_service)

    async def create_executions(
        self,
        context: ExecutionContext,
        payload: ExecutionCreateRequest,
    ) -> ExecutionCreateResponse:
        if not payload.requests:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="REQUESTS_EMPTY",
            )

        response_items: list[ExecutionItemResponse] = []

        for request in payload.requests:
            script = await self._validator.ensure_valid(context.tenant_id, request)
            charged = Decimal(str(script.execution_price))

            try:
                balance = self._billing.deduct(context.tenant_id, charged)
            except InsufficientBalance as exc:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="INSUFFICIENT_BALANCE",
                ) from exc

            execution = ExecutionRecord(
                id=generate_execution_id(),
                tenant_id=context.tenant_id,
                user_id=context.user_id,
                pc_id=payload.pc_id,
                device_id=request.device_id,
                script_id=script.id,
                script_version=script.version,
                status=ExecutionStatus.QUEUED,
                charged_amount=float(charged),
                created_at=datetime.now(timezone.utc),
                parameters=request.parameters,
            )

            await self._repository.create_execution(execution)
            self._dispatcher.enqueue(
                execution.device_id,
                DispatchTask(
                    execution_id=execution.id,
                    tenant_id=context.tenant_id,
                    device_id=execution.device_id,
                    payload={
                        "executionId": execution.id,
                        "scriptId": execution.script_id,
                        "scriptVersion": execution.script_version,
                        "parameters": execution.parameters,
                        "pcId": execution.pc_id,
                    },
                ),
            )
            await self._publisher.publish_execution_queued(
                context.tenant_id,
                {
                    "type": "EVENT",
                    "topic": "executions.progress",
                    "payload": {
                        "executionId": execution.id,
                        "status": execution.status.value,
                        "deviceId": execution.device_id,
                        "pcId": payload.pc_id,
                        "scriptId": execution.script_id,
                    },
                },
            )

            response_items.append(
                ExecutionItemResponse(
                    execution_id=execution.id,
                    device_id=execution.device_id,
                    status=execution.status.value,
                    charged=float(charged),
                    balance=float(balance),
                )
            )

        return ExecutionCreateResponse(executions=response_items)

    async def list_executions(
        self,
        tenant_id: str,
        filters: ExecutionListFilters,
    ) -> ExecutionListResponse:
        status_filter = ExecutionStatus(filters.status) if filters.status else None
        records = await self._repository.list_executions(
            tenant_id,
            script_id=filters.script_id,
            status=status_filter,
            device_id=filters.device_id,
            pc_id=filters.pc_id,
        )

        items = [
            ExecutionRecordResponse(
                execution_id=record.id,
                script_id=record.script_id,
                device_id=record.device_id,
                pc_id=record.pc_id,
                status=record.status.value,
                charged=record.charged_amount,
                created_at=record.created_at,
                parameters=record.parameters,
            )
            for record in sorted(records, key=lambda r: r.created_at, reverse=True)
        ]
        return ExecutionListResponse(records=items)

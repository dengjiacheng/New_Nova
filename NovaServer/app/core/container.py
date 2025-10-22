"""应用级服务容器与依赖管理。"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from app.core.config import Settings
from app.repositories.executions import ExecutionRepository, InMemoryExecutionRepository
from app.repositories.scripts import InMemoryScriptRepository, ScriptRepository
from app.services.billing import BillingLedger
from app.services.executions.orchestrator import (
    DispatcherGateway,
    ExecutionService,
    ExecutionValidator,
    LedgerBillingGateway,
    TenantEventPublisher,
)
from app.services.executions_dispatcher import ExecutionDispatcher
from app.services.pubsub import PubSubBus
from app.services.scripts import ScriptService


@dataclass
class ServiceContainer:
    """集中管理 NovaServer 运行期依赖。"""

    settings: Settings
    script_repository: ScriptRepository
    execution_repository: ExecutionRepository
    billing_ledger: BillingLedger
    dispatcher: ExecutionDispatcher
    event_bus: PubSubBus
    script_service: ScriptService
    execution_service: ExecutionService


def build_service_container(settings: Settings) -> ServiceContainer:
    """构建默认服务容器，供应用启动时注入。"""

    script_repository = InMemoryScriptRepository(InMemoryScriptRepository.demo_records())
    execution_repository = InMemoryExecutionRepository()
    billing_ledger = BillingLedger(Decimal(str(settings.demo_initial_balance)))
    dispatcher = ExecutionDispatcher()
    event_bus = PubSubBus()

    script_service = ScriptService(
        settings=settings,
        repository=script_repository,
        ledger=billing_ledger,
    )
    execution_service = ExecutionService(
        repository=execution_repository,
        script_service=script_service,
        billing=LedgerBillingGateway(billing_ledger),
        dispatcher=DispatcherGateway(dispatcher),
        publisher=TenantEventPublisher(event_bus),
        validator=ExecutionValidator(script_service),
    )

    return ServiceContainer(
        settings=settings,
        script_repository=script_repository,
        execution_repository=execution_repository,
        billing_ledger=billing_ledger,
        dispatcher=dispatcher,
        event_bus=event_bus,
        script_service=script_service,
        execution_service=execution_service,
    )

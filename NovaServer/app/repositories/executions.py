"""执行任务仓储接口与内存实现。"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Dict, Iterable, List, Optional
from uuid import uuid4


class ExecutionStatus(str, Enum):
    QUEUED = "QUEUED"
    RUNNING = "RUNNING"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    CANCELLED_DEVICE_OFFLINE = "CANCELLED_DEVICE_OFFLINE"
    CANCELLED_USER = "CANCELLED_USER"


@dataclass
class ExecutionRecord:
    id: str
    tenant_id: str
    user_id: str
    pc_id: str
    device_id: str
    script_id: str
    script_version: str
    status: ExecutionStatus
    charged_amount: float
    created_at: datetime
    parameters: dict


class ExecutionRepository:
    async def create_execution(self, record: ExecutionRecord) -> ExecutionRecord:
        raise NotImplementedError

    async def list_executions(
        self,
        tenant_id: str,
        *,
        script_id: Optional[str] = None,
        status: Optional[ExecutionStatus] = None,
        device_id: Optional[str] = None,
        pc_id: Optional[str] = None,
    ) -> List[ExecutionRecord]:
        raise NotImplementedError


class InMemoryExecutionRepository(ExecutionRepository):
    def __init__(self) -> None:
        self._records: Dict[str, List[ExecutionRecord]] = {}

    async def create_execution(self, record: ExecutionRecord) -> ExecutionRecord:
        self._records.setdefault(record.tenant_id, []).append(record)
        return record

    async def list_executions(
        self,
        tenant_id: str,
        *,
        script_id: Optional[str] = None,
        status: Optional[ExecutionStatus] = None,
        device_id: Optional[str] = None,
        pc_id: Optional[str] = None,
    ) -> List[ExecutionRecord]:
        records = list(self._records.get(tenant_id, []))

        def match(record: ExecutionRecord) -> bool:
            conditions = [
                script_id is None or record.script_id == script_id,
                status is None or record.status == status,
                device_id is None or record.device_id == device_id,
                pc_id is None or record.pc_id == pc_id,
            ]
            return all(conditions)

        return [record for record in records if match(record)]

    def reset(self) -> None:
        self._records.clear()


def generate_execution_id() -> str:
    return f"EXEC-{uuid4()}"

"""执行任务 API。"""

from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import Principal, get_current_principal, get_service_container
from app.api.responses import ok
from app.core.container import ServiceContainer
from app.schemas.executions import (
    ExecutionCreateRequest,
    ExecutionListFilters,
)
from app.services.executions import ExecutionContext, ExecutionService

router = APIRouter()


def get_execution_service(container: ServiceContainer = Depends(get_service_container)) -> ExecutionService:
    return container.execution_service


@router.post("", summary="批量创建执行任务")
async def create_executions(
    payload: ExecutionCreateRequest,
    principal: Principal = Depends(get_current_principal),
    execution_service: ExecutionService = Depends(get_execution_service),
):
    context = ExecutionContext(
        tenant_id=principal.tenant_id,
        user_id=principal.user_id,
        pc_id=principal.pc_id or payload.pc_id,
    )
    response = await execution_service.create_executions(context, payload)
    return ok(response)


@router.get("", summary="查询执行记录")
async def list_executions(
    script_id: Optional[str] = Query(default=None, alias="scriptId"),
    status: Optional[str] = None,
    device_id: Optional[str] = Query(default=None, alias="deviceId"),
    pc_id: Optional[str] = Query(default=None, alias="pcId"),
    principal: Principal = Depends(get_current_principal),
    execution_service: ExecutionService = Depends(get_execution_service),
):
    filters = ExecutionListFilters(
        script_id=script_id,
        status=status,
        device_id=device_id,
        pc_id=pc_id,
    )
    response = await execution_service.list_executions(principal.tenant_id, filters)
    return ok(response)

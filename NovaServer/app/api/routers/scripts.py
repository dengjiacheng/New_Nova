"""脚本目录与购买接口。"""

from fastapi import APIRouter, Depends

from app.api.dependencies import (
    Principal,
    get_current_principal,
    get_service_container,
)
from app.api.responses import ok
from app.core.container import ServiceContainer
from app.schemas.scripts import (
    PurchasedScriptsResponse,
    ScriptListResponse,
    ScriptPurchaseRequest,
    ScriptPurchaseResponse,
)
from app.services.scripts import ScriptService

router = APIRouter()


def get_script_service(container: ServiceContainer = Depends(get_service_container)) -> ScriptService:
    return container.script_service


@router.get(
    "",
    response_model=None,
    summary="查询可用脚本列表",
)
async def list_scripts(
    principal: Principal = Depends(get_current_principal),
    script_service: ScriptService = Depends(get_script_service),
) -> dict:
    response = await script_service.list_scripts(principal.tenant_id)
    return ok(response)


@router.get(
    "/purchased",
    response_model=None,
    summary="查询已购脚本",
)
async def list_purchased_scripts(
    principal: Principal = Depends(get_current_principal),
    script_service: ScriptService = Depends(get_script_service),
) -> dict:
    response = await script_service.list_purchased_scripts(principal.tenant_id)
    return ok(response)


@router.post(
    "/{script_id}/purchase",
    response_model=None,
    summary="购买脚本",
)
async def purchase_script(
    script_id: str,
    payload: ScriptPurchaseRequest,
    principal: Principal = Depends(get_current_principal),
    script_service: ScriptService = Depends(get_script_service),
) -> dict:
    response = await script_service.purchase_script(
        tenant_id=principal.tenant_id,
        user_id=principal.user_id,
        script_id=script_id,
        pc_id=payload.pc_id,
    )
    return ok(response)

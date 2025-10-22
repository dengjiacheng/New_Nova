"""健康检查路由。"""

from fastapi import APIRouter, Depends

from app.api.dependencies import get_app_settings
from app.core.config import Settings

router = APIRouter()


@router.get("/", summary="服务健康检查")
async def read_health(settings: Settings = Depends(get_app_settings)) -> dict[str, str]:
    return {
        "status": "ok",
        "service": settings.app_name,
        "environment": settings.environment,
    }

"""API 层依赖注入定义。"""

from __future__ import annotations

from collections.abc import AsyncGenerator
from dataclasses import dataclass
from typing import Optional

from fastapi import Depends, HTTPException, Request, status

from app.core.config import Settings, get_settings
from app.core.security import decode_jwt_token
from app.core.container import ServiceContainer


@dataclass
class Principal:
    user_id: str
    tenant_id: str
    username: str
    roles: list[str]
    pc_id: Optional[str] = None


async def get_app_settings() -> AsyncGenerator[Settings, None]:
    """获取全局配置，供路由/服务层使用。"""

    yield get_settings()


async def get_service_container(
    request: Request,
) -> AsyncGenerator[ServiceContainer, None]:
    """从 FastAPI 实例中获取服务容器。"""

    container: Optional[ServiceContainer] = getattr(request.app.state, "container", None)
    if container is None:
        raise RuntimeError("Service container not initialised")
    yield container


def settings_dependency() -> Settings:
    """同步依赖形式，便于非协程上下文调用。"""

    return get_settings()


async def get_current_principal(
    request: Request, settings: Settings = Depends(get_app_settings)
) -> Principal:
    """解析 JWT，返回当前请求主体信息。"""

    authorization = request.headers.get("Authorization")
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="AUTH_FAILED",
        )

    token = authorization.removeprefix("Bearer ").strip()
    try:
        payload = decode_jwt_token(settings, token)
    except Exception as exc:  # pragma: no cover - 统一转为认证失败
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="AUTH_FAILED",
        ) from exc

    tenant_id = payload.get("tenantId")
    user_id = payload.get("sub")
    if not tenant_id or not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="AUTH_FAILED",
        )

    roles = payload.get("roles") or []
    if not isinstance(roles, list):
        roles = [str(roles)]

    return Principal(
        user_id=str(user_id),
        tenant_id=str(tenant_id),
        username=str(payload.get("username", "")),
        roles=[str(role) for role in roles],
        pc_id=payload.get("pcId"),
    )

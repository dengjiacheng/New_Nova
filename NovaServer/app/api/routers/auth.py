"""认证路由实现。"""

from typing import Any, Dict

from fastapi import APIRouter, Depends

from app.api.dependencies import get_app_settings
from app.api.responses import ok
from app.core.config import Settings
from app.schemas.auth import (
    LoginRequest,
    LoginResponse,
    RefreshRequest,
    RefreshResponse,
)
from app.schemas.common import ApiResponse
from app.services.auth import AuthService, build_default_auth_service

router = APIRouter()


def get_auth_service(settings: Settings = Depends(get_app_settings)) -> AuthService:
    # TODO: 后续引入依赖注入容器，从请求中解析租户信息。
    return build_default_auth_service(settings)


@router.post(
    "/login",
    response_model=ApiResponse[LoginResponse],
    summary="账号密码登录",
)
async def login(
    payload: LoginRequest,
    auth_service: AuthService = Depends(get_auth_service),
) -> ApiResponse[LoginResponse]:
    result = await auth_service.login(payload.username, payload.password, payload.pc_id)
    return ok(LoginResponse(**result))


@router.post(
    "/refresh",
    response_model=ApiResponse[RefreshResponse],
    summary="刷新访问令牌",
)
async def refresh(
    payload: RefreshRequest,
    auth_service: AuthService = Depends(get_auth_service),
) -> ApiResponse[RefreshResponse]:
    result = await auth_service.refresh(payload.refreshToken)
    return ok(RefreshResponse(**result))


@router.post(
    "/logout",
    response_model=ApiResponse[Dict[str, Any]],
    summary="账号注销",
)
async def logout(
    auth_service: AuthService = Depends(get_auth_service),
) -> dict[str, Any]:
    await auth_service.logout()
    return ok({})

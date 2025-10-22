"""认证服务层。"""

from datetime import timedelta
from typing import Any

from fastapi import HTTPException, status

from app.core.config import Settings
from app.core.security import create_jwt_token, decode_jwt_token, verify_password
from app.repositories.user import InMemoryUserRepository, UserRecord, UserRepository


class AuthService:
    """负责登录、刷新与注销逻辑。"""

    def __init__(self, settings: Settings, user_repo: UserRepository) -> None:
        self._settings = settings
        self._user_repo = user_repo

    async def login(self, username: str, password: str, pc_id: str) -> dict[str, Any]:
        user = await self._user_repo.get_by_username(username)
        if not user or not verify_password(password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="AUTH_FAILED",
            )

        access_token = create_jwt_token(
            self._settings,
            subject=user.id,
            expires_in_minutes=self._settings.jwt_expire_minutes,
            extra_claims={
                "tenantId": user.tenant_id,
                "username": user.username,
                "roles": user.roles,
                "pcId": pc_id,
            },
        )
        refresh_token = create_jwt_token(
            self._settings,
            subject=user.id,
            expires_in_minutes=self._settings.jwt_refresh_expire_minutes,
            token_type="refresh",
            extra_claims={"pcId": pc_id, "username": user.username},
        )

        return {
            "token": access_token,
            "refreshToken": refresh_token,
            "tenant": {"id": user.tenant_id, "name": "Demo 租户"},
            "user": {"id": user.id, "roles": user.roles},
            "balance": 0.0,
        }

    async def refresh(self, refresh_token: str) -> dict[str, Any]:
        try:
            decoded = decode_jwt_token(self._settings, refresh_token)
        except Exception as exc:  # pragma: no cover - 内部转换为统一错误
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="AUTH_FAILED",
            ) from exc

        if decoded.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="AUTH_FAILED",
            )

        user = await self._user_repo.get_by_username(decoded.get("username", ""))
        # 刷新阶段若找不到用户，仍旧提示失败
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="AUTH_FAILED",
            )

        access_token = create_jwt_token(
            self._settings,
            subject=user.id,
            expires_in_minutes=self._settings.jwt_expire_minutes,
            extra_claims={
                "tenantId": user.tenant_id,
                "username": user.username,
                "roles": user.roles,
                "pcId": decoded.get("pcId"),
            },
        )

        return {"token": access_token}

    async def logout(self) -> None:
        # 当前阶段未持久化会话，后续可在此记录注销事件或撤销刷新 token。
        return None


def build_default_auth_service(settings: Settings) -> AuthService:
    demo_user = UserRecord(
        id="USR-DEMO",
        tenant_id="TEN-DEMO",
        username="demo",
        password_hash="$2b$12$ri7Kp73JO9V3UVJ4laoISuQXR9Os7oKmjQy4gKtoUPHrlxxC6LmOW",
        roles=["ADMIN"],
    )
    repo = InMemoryUserRepository(users=[demo_user])
    return AuthService(settings, repo)

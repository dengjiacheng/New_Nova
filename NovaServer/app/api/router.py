"""统一注册 FastAPI 路由。"""

from fastapi import APIRouter

from app.api.routers import agent_packages, auth, executions, health, scripts


def build_api_router() -> APIRouter:
    router = APIRouter()

    router.include_router(health.router, prefix="/health", tags=["health"])
    router.include_router(auth.router, prefix="/auth", tags=["auth"])
    router.include_router(scripts.router, prefix="/scripts", tags=["scripts"])
    router.include_router(
        agent_packages.admin_router,
        prefix="/admin/agent-packages",
        tags=["agent-packages"],
    )
    router.include_router(
        agent_packages.public_router,
        prefix="/agent-packages",
        tags=["agent-packages"],
    )
    router.include_router(executions.router, prefix="/executions", tags=["executions"])

    return router

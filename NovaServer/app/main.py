"""NovaServer FastAPI 应用入口。"""

from fastapi import FastAPI

from app.core.config import get_settings
from app.core.logging import init_logging
from app.core.container import build_service_container
from app.api.router import build_api_router
from app.api.routers import ws_agent, ws_pc
from app.workers import manager


def create_app() -> FastAPI:
    settings = get_settings()
    init_logging(settings)

    app = FastAPI(
        title=settings.app_name,
        debug=settings.debug,
        docs_url=f"{settings.api_prefix}/docs",
        openapi_url=f"{settings.api_prefix}/openapi.json",
    )

    app.state.container = build_service_container(settings)

    api_router = build_api_router()
    app.include_router(api_router, prefix=settings.api_prefix)
    app.include_router(ws_pc.router, prefix=settings.websocket_prefix)
    app.include_router(ws_agent.router, prefix=settings.websocket_prefix)

    @app.on_event("startup")
    async def _start_workers() -> None:
        await manager.start(app.state.container)

    @app.on_event("shutdown")
    async def _stop_workers() -> None:
        await manager.stop()

    return app


app = create_app()

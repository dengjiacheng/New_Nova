"""Agent APK 包管理接口。"""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import FileResponse

from app.api.dependencies import Principal, get_app_settings, get_current_principal
from app.api.responses import ok
from app.core.config import Settings
from app.db.session import get_db_session
from app.services.agent_packages import (
    AgentPackageService,
    build_agent_package_service,
)
from sqlalchemy.ext.asyncio import AsyncSession

admin_router = APIRouter()
public_router = APIRouter()


def get_agent_package_service(
    settings: Settings = Depends(get_app_settings),
    session: AsyncSession = Depends(get_db_session),
) -> AgentPackageService:
    return build_agent_package_service(settings, session)


def _ensure_admin(principal: Principal, *, require_super_admin: bool = False) -> None:
    roles = {role.upper() for role in principal.roles}
    allowed = {"ADMIN", "SUPER_ADMIN"}
    if require_super_admin:
        if "SUPER_ADMIN" not in roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="FORBIDDEN")
    elif not roles.intersection(allowed):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="FORBIDDEN")


@admin_router.get(
    "",
    summary="列出 Agent APK 包",
    response_model=None,
)
async def list_agent_packages(
    principal: Principal = Depends(get_current_principal),
    service: AgentPackageService = Depends(get_agent_package_service),
) -> dict:
    _ensure_admin(principal)
    response = await service.list_packages()
    return ok(response)


@admin_router.post(
    "",
    summary="上传 Agent APK 包",
    response_model=None,
)
async def upload_agent_package(
    file: UploadFile = File(...),
    version_name: str = Form(..., alias="versionName"),
    version_code: int = Form(..., alias="versionCode"),
    release_notes: Optional[str] = Form(None, alias="releaseNotes"),
    checksum: Optional[str] = Form(None),
    principal: Principal = Depends(get_current_principal),
    service: AgentPackageService = Depends(get_agent_package_service),
) -> dict:
    _ensure_admin(principal)
    payload = await service.upload_package(
        principal=principal,
        file=file,
        version_name=version_name,
        version_code=version_code,
        release_notes=release_notes,
        checksum=checksum,
    )
    return ok(payload)


@admin_router.post(
    "/{package_id}/activate",
    summary="激活指定 Agent APK",
    response_model=None,
)
async def activate_agent_package(
    package_id: str,
    principal: Principal = Depends(get_current_principal),
    service: AgentPackageService = Depends(get_agent_package_service),
) -> dict:
    _ensure_admin(principal)
    await service.activate_package(package_id, principal)
    return ok({})


@admin_router.delete(
    "/{package_id}",
    summary="删除 Agent APK",
    response_model=None,
)
async def delete_agent_package(
    package_id: str,
    principal: Principal = Depends(get_current_principal),
    service: AgentPackageService = Depends(get_agent_package_service),
) -> dict:
    _ensure_admin(principal)
    await service.delete_package(package_id)
    return ok({})


@admin_router.get(
    "/{package_id}/download",
    summary="下载 Agent APK",
)
async def download_agent_package(
    package_id: str,
    principal: Principal = Depends(get_current_principal),
    service: AgentPackageService = Depends(get_agent_package_service),
) -> FileResponse:
    _ensure_admin(principal)
    path, record = await service.get_download(package_id)
    return FileResponse(
        path,
        media_type="application/vnd.android.package-archive",
        filename=record.file_name,
    )


@public_router.get(
    "/latest",
    summary="获取当前激活的 Agent 包",
    response_model=None,
)
async def latest_agent_package(
    service: AgentPackageService = Depends(get_agent_package_service),
) -> dict:
    response = await service.get_latest()
    return ok(response)

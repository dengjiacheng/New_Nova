"""Agent APK 包管理服务实现。"""

from __future__ import annotations

import hashlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from fastapi import HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import Principal
from app.core.config import Settings
from app.repositories.agent_packages import (
    AgentPackageRecord,
    AgentPackageRepository,
    AgentPackageStatus,
    SqlAgentPackageRepository,
)
from app.schemas.agent_packages import (
    AgentPackageItem,
    AgentPackageListResponse,
    AgentPackageUploadResponse,
    LatestAgentPackageResponse,
)


class AgentPackageService:
    def __init__(
        self,
        settings: Settings,
        repository: AgentPackageRepository,
        session: AsyncSession,
    ) -> None:
        self._settings = settings
        self._repository = repository
        self._session = session
        self._storage_dir = Path(settings.agent_package_storage_dir)
        self._storage_dir.mkdir(parents=True, exist_ok=True)

    async def list_packages(self) -> AgentPackageListResponse:
        records = await self._repository.list()
        items = [self._to_item(record) for record in records]
        return AgentPackageListResponse(items=items)

    async def upload_package(
        self,
        *,
        principal: Principal,
        file: UploadFile,
        version_name: str,
        version_code: int,
        release_notes: Optional[str],
        checksum: Optional[str],
    ) -> AgentPackageUploadResponse:
        package_id = self._generate_package_id()
        file_name = file.filename or f"{package_id}.apk"
        storage_path = self._storage_dir / f"{package_id}.apk"

        computed_checksum, file_size = await self._save_file(file, storage_path)
        provided_checksum = checksum.strip() if checksum else None
        if provided_checksum and provided_checksum.lower() != computed_checksum.lower():
            await self._cleanup_file(storage_path)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="CHECKSUM_MISMATCH",
            )

        normalized_release_notes = (
            release_notes.strip() if release_notes and release_notes.strip() else None
        )

        record = AgentPackageRecord(
            package_id=package_id,
            version_name=version_name,
            version_code=version_code,
            file_name=file_name,
            file_size=file_size,
            checksum=computed_checksum,
            status=AgentPackageStatus.DRAFT,
            storage_path=str(storage_path),
            release_notes=normalized_release_notes,
            uploaded_by=principal.user_id,
            uploaded_by_name=principal.username or None,
            uploaded_at=datetime.now(timezone.utc),
            tenant_id=principal.tenant_id,
        )
        await self._repository.add(record)
        await self._session.commit()
        item = self._to_item(record)
        return AgentPackageUploadResponse(**item.model_dump())

    async def activate_package(self, package_id: str, principal: Principal) -> None:
        record = await self._repository.get(package_id)
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="AGENT_PACKAGE_NOT_FOUND",
            )
        try:
            await self._repository.set_active(package_id, principal.user_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="AGENT_PACKAGE_NOT_FOUND",
            ) from None
        await self._session.commit()

    async def delete_package(self, package_id: str) -> None:
        record = await self._repository.get(package_id)
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="AGENT_PACKAGE_NOT_FOUND",
            )
        path = Path(record.storage_path)
        await self._repository.delete(package_id)
        await self._session.commit()
        if path.exists():
            try:
                path.unlink()
            except OSError:
                pass

    async def get_latest(self) -> LatestAgentPackageResponse:
        record = await self._repository.get_active()
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="AGENT_PACKAGE_NOT_FOUND",
            )
        return LatestAgentPackageResponse(**self._to_item(record).model_dump())

    async def get_download(self, package_id: str) -> tuple[Path, AgentPackageRecord]:
        record = await self._repository.get(package_id)
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="AGENT_PACKAGE_NOT_FOUND",
            )
        path = Path(record.storage_path)
        if not path.exists():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="AGENT_PACKAGE_FILE_MISSING",
            )
        return path, record

    async def _save_file(self, upload: UploadFile, destination: Path) -> tuple[str, int]:
        hasher = hashlib.sha256()
        size = 0
        # ensure parent directory exists (in case path changed at runtime)
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("wb") as outfile:
            while True:
                chunk = await upload.read(1024 * 1024)
                if not chunk:
                    break
                outfile.write(chunk)
                hasher.update(chunk)
                size += len(chunk)
        await upload.close()
        checksum = f"sha256:{hasher.hexdigest()}"
        return checksum, size

    async def _cleanup_file(self, path: Path) -> None:
        if path.exists():
            try:
                path.unlink()
            except OSError:
                # ignore cleanup error
                pass

    def _to_item(self, record: AgentPackageRecord) -> AgentPackageItem:
        download_url = f"{self._settings.api_prefix}/admin/agent-packages/{record.package_id}/download"
        return AgentPackageItem(
            package_id=record.package_id,
            version_name=record.version_name,
            version_code=record.version_code,
            file_size=record.file_size,
            checksum=record.checksum,
            status=record.status.value,
            uploaded_at=record.uploaded_at,
            uploaded_by={
                "id": record.uploaded_by,
                "name": record.uploaded_by_name,
            },
            download_url=download_url,
            release_notes=record.release_notes,
            tenant_id=record.tenant_id,
        )

    def _generate_package_id(self) -> str:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S%f")
        return f"AGP-{timestamp}"


def build_agent_package_service(
    settings: Settings,
    session: AsyncSession,
) -> AgentPackageService:
    repository = SqlAgentPackageRepository(session)
    return AgentPackageService(settings, repository, session)

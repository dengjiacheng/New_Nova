"""Agent APK 包仓储接口与实现。"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent_package import AgentPackage, AgentPackageStatus


@dataclass
class AgentPackageRecord:
    package_id: str
    version_name: str
    version_code: int
    file_name: str
    file_size: int
    checksum: str
    storage_path: str
    status: AgentPackageStatus = AgentPackageStatus.DRAFT
    release_notes: Optional[str] = None
    uploaded_by: str = ""
    uploaded_by_name: Optional[str] = None
    uploaded_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    tenant_id: Optional[str] = None
    activated_by: Optional[str] = None
    activated_at: Optional[datetime] = None


class AgentPackageRepository:
    async def add(self, record: AgentPackageRecord) -> None:
        raise NotImplementedError

    async def list(self) -> List[AgentPackageRecord]:
        raise NotImplementedError

    async def get(self, package_id: str) -> Optional[AgentPackageRecord]:
        raise NotImplementedError

    async def set_active(self, package_id: str, activated_by: Optional[str]) -> None:
        raise NotImplementedError

    async def delete(self, package_id: str) -> None:
        raise NotImplementedError

    async def get_active(self) -> Optional[AgentPackageRecord]:
        raise NotImplementedError


class SqlAgentPackageRepository(AgentPackageRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add(self, record: AgentPackageRecord) -> None:
        entity = AgentPackage(
            id=record.package_id,
            version_name=record.version_name,
            version_code=record.version_code,
            file_name=record.file_name,
            file_size=record.file_size,
            checksum=record.checksum,
            status=record.status,
            storage_path=record.storage_path,
            release_notes=record.release_notes,
            uploaded_by=record.uploaded_by,
            uploaded_by_name=record.uploaded_by_name,
            uploaded_at=record.uploaded_at,
            tenant_id=record.tenant_id,
            activated_by=record.activated_by,
            activated_at=record.activated_at,
        )
        self._session.add(entity)
        await self._session.flush()

    async def list(self) -> List[AgentPackageRecord]:
        result = await self._session.execute(
            select(AgentPackage).order_by(AgentPackage.uploaded_at.desc())
        )
        return [self._to_record(entity) for entity in result.scalars().all()]

    async def get(self, package_id: str) -> Optional[AgentPackageRecord]:
        entity = await self._session.get(AgentPackage, package_id)
        if not entity:
            return None
        return self._to_record(entity)

    async def set_active(self, package_id: str, activated_by: Optional[str]) -> None:
        now = datetime.now(timezone.utc)
        await self._session.execute(
            update(AgentPackage)
            .where(AgentPackage.status == AgentPackageStatus.ACTIVE)
            .values(status=AgentPackageStatus.ARCHIVED)
        )
        result = await self._session.execute(
            update(AgentPackage)
            .where(AgentPackage.id == package_id)
            .values(
                status=AgentPackageStatus.ACTIVE,
                activated_at=now,
                activated_by=activated_by,
            )
        )
        if result.rowcount == 0:
            raise ValueError("package_not_found")

    async def delete(self, package_id: str) -> None:
        await self._session.execute(
            delete(AgentPackage).where(AgentPackage.id == package_id)
        )

    async def get_active(self) -> Optional[AgentPackageRecord]:
        result = await self._session.execute(
            select(AgentPackage)
            .where(AgentPackage.status == AgentPackageStatus.ACTIVE)
            .order_by(AgentPackage.activated_at.desc().nullslast())
            .limit(1)
        )
        entity = result.scalars().first()
        if not entity:
            return None
        return self._to_record(entity)

    def _to_record(self, entity: AgentPackage) -> AgentPackageRecord:
        return AgentPackageRecord(
            package_id=entity.id,
            version_name=entity.version_name,
            version_code=entity.version_code,
            file_name=entity.file_name,
            file_size=entity.file_size,
            checksum=entity.checksum,
            storage_path=entity.storage_path,
            status=entity.status,
            release_notes=entity.release_notes,
            uploaded_by=entity.uploaded_by,
            uploaded_by_name=entity.uploaded_by_name,
            uploaded_at=entity.uploaded_at,
            tenant_id=entity.tenant_id,
            activated_by=entity.activated_by,
            activated_at=entity.activated_at,
        )

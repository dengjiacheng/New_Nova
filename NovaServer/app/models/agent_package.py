"""Agent APK 元数据 ORM 模型。"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Optional
from uuid import uuid4

from sqlalchemy import DateTime, Enum as SAEnum, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AgentPackageStatus(str, Enum):
    DRAFT = "DRAFT"
    ACTIVE = "ACTIVE"
    ARCHIVED = "ARCHIVED"


class AgentPackage(Base):
    __tablename__ = "agent_packages"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    version_name: Mapped[str] = mapped_column(String(64), nullable=False)
    version_code: Mapped[int] = mapped_column(Integer, nullable=False)
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    file_size: Mapped[int] = mapped_column(Integer, nullable=False)
    checksum: Mapped[str] = mapped_column(String(128), nullable=False)
    storage_path: Mapped[str] = mapped_column(String(512), nullable=False)
    status: Mapped[AgentPackageStatus] = mapped_column(
        SAEnum(AgentPackageStatus, name="agent_package_status"),
        nullable=False,
        default=AgentPackageStatus.DRAFT,
    )
    release_notes: Mapped[Optional[str]] = mapped_column(Text)
    uploaded_by: Mapped[str] = mapped_column(String(36), nullable=False)
    uploaded_by_name: Mapped[Optional[str]] = mapped_column(String(128))
    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    tenant_id: Mapped[Optional[str]] = mapped_column(String(36))
    activated_by: Mapped[Optional[str]] = mapped_column(String(36))
    activated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))

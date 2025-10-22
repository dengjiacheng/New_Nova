"""租户相关模型。"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import TYPE_CHECKING, List
from uuid import uuid4

from sqlalchemy import DateTime, Enum as PgEnum, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class TenantStatus(str, Enum):
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"


if TYPE_CHECKING:
    from app.models.audit import AuditLog
    from app.models.execution import Execution
    from app.models.scripts import ScriptPurchase
    from app.models.transactions import Transaction
    from app.models.assets import ExecutionAsset
    from app.models.user import User


class Tenant(Base):
    __tablename__ = "tenants"

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        primary_key=True,
        default=lambda: str(uuid4()),
    )
    name: Mapped[str] = mapped_column(String(128), nullable=False, unique=True)
    status: Mapped[TenantStatus] = mapped_column(
        PgEnum(TenantStatus, name="tenant_status"),
        nullable=False,
        default=TenantStatus.ACTIVE,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    balance: Mapped["TenantBalance"] = relationship(
        back_populates="tenant", uselist=False, cascade="all, delete-orphan"
    )
    users: Mapped[List["User"]] = relationship(
        back_populates="tenant", cascade="all, delete-orphan"
    )
    executions: Mapped[List["Execution"]] = relationship(
        back_populates="tenant", cascade="all, delete-orphan"
    )
    script_purchases: Mapped[List["ScriptPurchase"]] = relationship(
        back_populates="tenant", cascade="all, delete-orphan"
    )
    transactions: Mapped[List["Transaction"]] = relationship(
        back_populates="tenant", cascade="all, delete-orphan"
    )
    audit_logs: Mapped[List["AuditLog"]] = relationship(
        back_populates="tenant", cascade="all, delete-orphan"
    )
    execution_assets: Mapped[List["ExecutionAsset"]] = relationship(
        back_populates="tenant", cascade="all, delete-orphan"
    )


class TenantBalance(Base):
    __tablename__ = "tenant_balances"

    tenant_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("tenants.id", ondelete="CASCADE"),
        primary_key=True,
    )
    balance: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    frozen: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    tenant: Mapped[Tenant] = relationship(back_populates="balance")

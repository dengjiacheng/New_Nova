"""用户相关模型。"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import TYPE_CHECKING, List
from uuid import uuid4

from sqlalchemy import DateTime, Enum as PgEnum, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.tenant import Tenant

if TYPE_CHECKING:
    from app.models.assets import ExecutionAsset
    from app.models.audit import AuditLog
    from app.models.execution import Execution
    from app.models.scripts import ScriptPurchase
    from app.models.transactions import Transaction


class UserRole(str, Enum):
    SUPER_ADMIN = "SUPER_ADMIN"
    ADMIN = "ADMIN"
    USER = "USER"


class UserStatus(str, Enum):
    ACTIVE = "ACTIVE"
    DISABLED = "DISABLED"


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), primary_key=True, default=lambda: str(uuid4())
    )
    tenant_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
    )
    username: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[UserRole] = mapped_column(
        PgEnum(UserRole, name="user_role"), nullable=False, default=UserRole.USER
    )
    status: Mapped[UserStatus] = mapped_column(
        PgEnum(UserStatus, name="user_status"),
        nullable=False,
        default=UserStatus.ACTIVE,
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

    tenant: Mapped[Tenant] = relationship(back_populates="users")
    executions: Mapped[List["Execution"]] = relationship(back_populates="user")
    transactions: Mapped[List["Transaction"]] = relationship(back_populates="user")
    script_purchases: Mapped[List["ScriptPurchase"]] = relationship(
        back_populates="user"
    )
    audit_logs: Mapped[List["AuditLog"]] = relationship(back_populates="user")
    execution_assets: Mapped[List["ExecutionAsset"]] = relationship(
        back_populates="user"
    )

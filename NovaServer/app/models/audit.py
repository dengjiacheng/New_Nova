"""审计日志模型。"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import TYPE_CHECKING, Any, Dict, Optional
from uuid import uuid4

from sqlalchemy import DateTime, Enum as PgEnum, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.types import JSONB_COMPAT

if TYPE_CHECKING:
    from app.models.tenant import Tenant
    from app.models.user import User


class AuditAction(str, Enum):
    SCRIPT_EXECUTE = "SCRIPT_EXECUTE"
    SCRIPT_PURCHASE = "SCRIPT_PURCHASE"
    LOGIN = "LOGIN"
    EXECUTION_RESULT = "EXECUTION_RESULT"
    BALANCE_ADJUST = "BALANCE_ADJUST"


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), primary_key=True, default=lambda: str(uuid4())
    )
    tenant_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[Optional[str]] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("users.id", ondelete="SET NULL"),
    )
    pc_id: Mapped[Optional[str]] = mapped_column(String(64))
    action: Mapped[AuditAction] = mapped_column(
        PgEnum(AuditAction, name="audit_action"), nullable=False
    )
    target_id: Mapped[Optional[str]] = mapped_column(String(128))
    metadata_: Mapped[Optional[Dict[str, Any]]] = mapped_column(
        "metadata", JSONB_COMPAT
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    tenant: Mapped["Tenant"] = relationship(back_populates="audit_logs")
    user: Mapped[Optional["User"]] = relationship(back_populates="audit_logs")

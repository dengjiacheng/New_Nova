"""执行任务模型。"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import TYPE_CHECKING, Any, Dict, List, Optional
from uuid import uuid4

from sqlalchemy import DateTime, Enum as PgEnum, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.types import JSONB_COMPAT

if TYPE_CHECKING:
    from app.models.scripts import Script
    from app.models.tenant import Tenant
    from app.models.user import User
    from app.models.transactions import Transaction


class ExecutionStatus(str, Enum):
    QUEUED = "QUEUED"
    RUNNING = "RUNNING"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    CANCELLED_DEVICE_OFFLINE = "CANCELLED_DEVICE_OFFLINE"
    CANCELLED_USER = "CANCELLED_USER"


class Execution(Base):
    __tablename__ = "executions"

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False), primary_key=True, default=lambda: str(uuid4())
    )
    tenant_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    pc_id: Mapped[str] = mapped_column(String(64), nullable=False)
    device_id: Mapped[str] = mapped_column(String(128), nullable=False)
    script_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("scripts.id", ondelete="CASCADE"),
        nullable=False,
    )
    script_version: Mapped[str] = mapped_column(String(32), nullable=False)
    parameters: Mapped[Dict[str, Any]] = mapped_column(JSONB_COMPAT, nullable=False)
    status: Mapped[ExecutionStatus] = mapped_column(
        PgEnum(ExecutionStatus, name="execution_status"),
        nullable=False,
        default=ExecutionStatus.QUEUED,
    )
    charged_amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    result_summary: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSONB_COMPAT)
    started_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    finished_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    tenant: Mapped["Tenant"] = relationship(back_populates="executions")
    user: Mapped[Optional["User"]] = relationship(back_populates="executions")
    script: Mapped["Script"] = relationship(back_populates="executions")
    transaction: Mapped[Optional["Transaction"]] = relationship(
        back_populates="execution", uselist=False
    )
    events: Mapped[List["ExecutionEvent"]] = relationship(
        back_populates="execution", cascade="all, delete-orphan"
    )


class ExecutionEventType(str, Enum):
    STEP = "STEP"
    LOG = "LOG"
    ATTACHMENT = "ATTACHMENT"


class ExecutionEvent(Base):
    __tablename__ = "execution_events"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    execution_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("executions.id", ondelete="CASCADE"),
        nullable=False,
    )
    event_type: Mapped[ExecutionEventType] = mapped_column(
        PgEnum(ExecutionEventType, name="execution_event_type"), nullable=False
    )
    event_payload: Mapped[Dict[str, Any]] = mapped_column(JSONB_COMPAT, nullable=False)
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    execution: Mapped["Execution"] = relationship(back_populates="events")

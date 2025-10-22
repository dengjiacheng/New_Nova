"""脚本与授权模型。"""

from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING, Any, Dict, List, Optional
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, Numeric, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.types import JSONB_COMPAT

if TYPE_CHECKING:
    from app.models.execution import Execution
    from app.models.tenant import Tenant
    from app.models.transactions import Transaction
    from app.models.user import User


class Script(Base):
    __tablename__ = "scripts"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(1024))
    latest_version: Mapped[str] = mapped_column(String(32), nullable=False)
    purchase_price: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    execution_price: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    capabilities: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSONB_COMPAT, default=dict)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    purchases: Mapped[List["ScriptPurchase"]] = relationship(
        back_populates="script", cascade="all, delete-orphan"
    )
    executions: Mapped[List["Execution"]] = relationship(back_populates="script")


class ScriptPurchase(Base):
    __tablename__ = "script_purchases"
    __table_args__ = (UniqueConstraint("tenant_id", "script_id", name="uq_script_purchase"),)

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
    script_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("scripts.id", ondelete="CASCADE"),
        nullable=False,
    )
    script_version: Mapped[str] = mapped_column(String(32), nullable=False)
    price: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    purchased_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    tenant: Mapped["Tenant"] = relationship(back_populates="script_purchases")
    user: Mapped[Optional["User"]] = relationship(back_populates="script_purchases")
    script: Mapped["Script"] = relationship(back_populates="purchases")
    transaction: Mapped[Optional["Transaction"]] = relationship(
        back_populates="script_purchase", uselist=False
    )

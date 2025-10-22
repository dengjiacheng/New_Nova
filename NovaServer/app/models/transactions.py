"""计费与交易模型。"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import TYPE_CHECKING, Optional
from uuid import uuid4

from sqlalchemy import DateTime, Enum as PgEnum, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.execution import Execution
    from app.models.scripts import ScriptPurchase
    from app.models.tenant import Tenant
    from app.models.user import User


class TransactionType(str, Enum):
    PURCHASE = "PURCHASE"
    EXECUTION = "EXECUTION"
    RECHARGE = "RECHARGE"
    ADJUSTMENT = "ADJUSTMENT"


class Transaction(Base):
    __tablename__ = "transactions"

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
    type: Mapped[TransactionType] = mapped_column(
        PgEnum(TransactionType, name="transaction_type"), nullable=False
    )
    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    script_id: Mapped[Optional[str]] = mapped_column(String(64))
    execution_id: Mapped[Optional[str]] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("executions.id", ondelete="SET NULL"),
    )
    script_purchase_id: Mapped[Optional[str]] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("script_purchases.id", ondelete="SET NULL"),
    )
    reference: Mapped[Optional[str]] = mapped_column(String(128))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    tenant: Mapped["Tenant"] = relationship(back_populates="transactions")
    user: Mapped[Optional["User"]] = relationship(back_populates="transactions")
    execution: Mapped[Optional["Execution"]] = relationship(back_populates="transaction")
    script_purchase: Mapped[Optional["ScriptPurchase"]] = relationship(
        back_populates="transaction"
    )

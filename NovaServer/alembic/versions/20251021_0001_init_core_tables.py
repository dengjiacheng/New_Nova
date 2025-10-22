"""init core tables

Revision ID: 20251021_0001
Revises: 
Create Date: 2025-10-21
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql as pg


# revision identifiers, used by Alembic.
revision = "20251021_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    tenant_status = sa.Enum("ACTIVE", "SUSPENDED", name="tenant_status")
    user_role = sa.Enum("SUPER_ADMIN", "ADMIN", "USER", name="user_role")
    user_status = sa.Enum("ACTIVE", "DISABLED", name="user_status")
    execution_status = sa.Enum(
        "QUEUED",
        "RUNNING",
        "SUCCESS",
        "FAILED",
        "CANCELLED_DEVICE_OFFLINE",
        "CANCELLED_USER",
        name="execution_status",
    )
    execution_event_type = sa.Enum(
        "STEP", "LOG", "ATTACHMENT", name="execution_event_type"
    )
    transaction_type = sa.Enum(
        "PURCHASE", "EXECUTION", "RECHARGE", "ADJUSTMENT", name="transaction_type"
    )
    audit_action = sa.Enum(
        "SCRIPT_EXECUTE",
        "SCRIPT_PURCHASE",
        "LOGIN",
        "EXECUTION_RESULT",
        "BALANCE_ADJUST",
        name="audit_action",
    )

    op.create_table(
        "tenants",
        sa.Column("id", pg.UUID(as_uuid=False), primary_key=True),
        sa.Column("name", sa.String(length=128), nullable=False, unique=True),
        sa.Column("status", tenant_status, nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
    )

    op.create_table(
        "tenant_balances",
        sa.Column("tenant_id", pg.UUID(as_uuid=False), primary_key=True),
        sa.Column(
            "balance",
            sa.Numeric(12, 2),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column(
            "frozen",
            sa.Numeric(12, 2),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"], ondelete="CASCADE"),
    )

    op.create_table(
        "users",
        sa.Column("id", pg.UUID(as_uuid=False), primary_key=True),
        sa.Column("tenant_id", pg.UUID(as_uuid=False), nullable=False),
        sa.Column("username", sa.String(length=64), nullable=False, unique=True),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("role", user_role, nullable=False),
        sa.Column("status", user_status, nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"], ondelete="CASCADE"),
    )

    op.create_table(
        "scripts",
        sa.Column("id", sa.String(length=64), primary_key=True),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("description", sa.String(length=1024)),
        sa.Column("latest_version", sa.String(length=32), nullable=False),
        sa.Column("purchase_price", sa.Numeric(10, 2), nullable=False),
        sa.Column("execution_price", sa.Numeric(10, 2), nullable=False),
        sa.Column(
            "capabilities",
            pg.JSONB(astext_type=sa.Text()),
            nullable=True,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
    )

    op.create_table(
        "script_purchases",
        sa.Column("id", pg.UUID(as_uuid=False), primary_key=True),
        sa.Column("tenant_id", pg.UUID(as_uuid=False), nullable=False),
        sa.Column("user_id", pg.UUID(as_uuid=False)),
        sa.Column("script_id", sa.String(length=64), nullable=False),
        sa.Column("script_version", sa.String(length=32), nullable=False),
        sa.Column("price", sa.Numeric(10, 2), nullable=False),
        sa.Column(
            "purchased_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["script_id"], ["scripts.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("tenant_id", "script_id", name="uq_script_purchase"),
    )

    op.create_table(
        "executions",
        sa.Column("id", pg.UUID(as_uuid=False), primary_key=True),
        sa.Column("tenant_id", pg.UUID(as_uuid=False), nullable=False),
        sa.Column("user_id", pg.UUID(as_uuid=False)),
        sa.Column("pc_id", sa.String(length=64), nullable=False),
        sa.Column("device_id", sa.String(length=128), nullable=False),
        sa.Column("script_id", sa.String(length=64), nullable=False),
        sa.Column("script_version", sa.String(length=32), nullable=False),
        sa.Column("parameters", pg.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("status", execution_status, nullable=False),
        sa.Column("charged_amount", sa.Numeric(10, 2), nullable=False),
        sa.Column("result_summary", pg.JSONB(astext_type=sa.Text())),
        sa.Column("started_at", sa.DateTime(timezone=True)),
        sa.Column("finished_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["script_id"], ["scripts.id"], ondelete="CASCADE"),
    )

    op.create_table(
        "execution_events",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("execution_id", pg.UUID(as_uuid=False), nullable=False),
        sa.Column("event_type", execution_event_type, nullable=False),
        sa.Column("event_payload", pg.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column(
            "timestamp",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.ForeignKeyConstraint(
            ["execution_id"], ["executions.id"], ondelete="CASCADE"
        ),
    )

    op.create_table(
        "transactions",
        sa.Column("id", pg.UUID(as_uuid=False), primary_key=True),
        sa.Column("tenant_id", pg.UUID(as_uuid=False), nullable=False),
        sa.Column("user_id", pg.UUID(as_uuid=False)),
        sa.Column("pc_id", sa.String(length=64)),
        sa.Column("type", transaction_type, nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("script_id", sa.String(length=64)),
        sa.Column("execution_id", pg.UUID(as_uuid=False)),
        sa.Column("script_purchase_id", pg.UUID(as_uuid=False)),
        sa.Column("reference", sa.String(length=128)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["execution_id"], ["executions.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["script_purchase_id"],
            ["script_purchases.id"],
            ondelete="SET NULL",
        ),
    )

    op.create_table(
        "execution_assets",
        sa.Column("id", pg.UUID(as_uuid=False), primary_key=True),
        sa.Column("tenant_id", pg.UUID(as_uuid=False), nullable=False),
        sa.Column("user_id", pg.UUID(as_uuid=False)),
        sa.Column("pc_id", sa.String(length=64)),
        sa.Column("script_id", sa.String(length=64)),
        sa.Column("field", sa.String(length=64)),
        sa.Column("file_name", sa.String(length=255), nullable=False),
        sa.Column("content_type", sa.String(length=128), nullable=False),
        sa.Column("size", sa.Integer(), nullable=False),
        sa.Column("storage_key", sa.String(length=255), nullable=False),
        sa.Column("download_url", sa.String(length=512)),
        sa.Column("expires_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
    )

    op.create_table(
        "audit_logs",
        sa.Column("id", pg.UUID(as_uuid=False), primary_key=True),
        sa.Column("tenant_id", pg.UUID(as_uuid=False), nullable=False),
        sa.Column("user_id", pg.UUID(as_uuid=False)),
        sa.Column("pc_id", sa.String(length=64)),
        sa.Column("action", audit_action, nullable=False),
        sa.Column("target_id", sa.String(length=128)),
        sa.Column("metadata", pg.JSONB(astext_type=sa.Text())),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
    )


def downgrade() -> None:
    op.drop_table("audit_logs")
    op.drop_table("execution_assets")
    op.drop_table("transactions")
    op.drop_table("execution_events")
    op.drop_table("executions")
    op.drop_table("script_purchases")
    op.drop_table("scripts")
    op.drop_table("users")
    op.drop_table("tenant_balances")
    op.drop_table("tenants")

    bind = op.get_bind()
    sa.Enum(
        "SCRIPT_EXECUTE",
        "SCRIPT_PURCHASE",
        "LOGIN",
        "EXECUTION_RESULT",
        "BALANCE_ADJUST",
        name="audit_action",
    ).drop(bind, checkfirst=True)
    sa.Enum(
        "PURCHASE",
        "EXECUTION",
        "RECHARGE",
        "ADJUSTMENT",
        name="transaction_type",
    ).drop(bind, checkfirst=True)
    sa.Enum("STEP", "LOG", "ATTACHMENT", name="execution_event_type").drop(
        bind, checkfirst=True
    )
    sa.Enum(
        "QUEUED",
        "RUNNING",
        "SUCCESS",
        "FAILED",
        "CANCELLED_DEVICE_OFFLINE",
        "CANCELLED_USER",
        name="execution_status",
    ).drop(bind, checkfirst=True)
    sa.Enum("ACTIVE", "DISABLED", name="user_status").drop(bind, checkfirst=True)
    sa.Enum("SUPER_ADMIN", "ADMIN", "USER", name="user_role").drop(
        bind, checkfirst=True
    )
    sa.Enum("ACTIVE", "SUSPENDED", name="tenant_status").drop(bind, checkfirst=True)

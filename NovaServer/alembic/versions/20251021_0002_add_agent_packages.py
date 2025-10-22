"""add agent packages table

Revision ID: 20251021_0002
Revises: 20251021_0001
Create Date: 2025-10-21
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "20251021_0002"
down_revision = "20251021_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    agent_package_status = sa.Enum(
        "DRAFT",
        "ACTIVE",
        "ARCHIVED",
        name="agent_package_status",
    )

    op.create_table(
        "agent_packages",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("version_name", sa.String(length=64), nullable=False),
        sa.Column("version_code", sa.Integer(), nullable=False),
        sa.Column("file_name", sa.String(length=255), nullable=False),
        sa.Column("file_size", sa.Integer(), nullable=False),
        sa.Column("checksum", sa.String(length=128), nullable=False),
        sa.Column("storage_path", sa.String(length=512), nullable=False),
        sa.Column("status", agent_package_status, nullable=False, server_default="DRAFT"),
        sa.Column("release_notes", sa.Text()),
        sa.Column("uploaded_by", sa.String(length=36), nullable=False),
        sa.Column("uploaded_by_name", sa.String(length=128)),
        sa.Column(
            "uploaded_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.Column("tenant_id", sa.String(length=36)),
        sa.Column("activated_by", sa.String(length=36)),
        sa.Column("activated_at", sa.DateTime(timezone=True)),
    )

    op.create_index(
        "ix_agent_packages_status",
        "agent_packages",
        ["status"],
    )


def downgrade() -> None:
    op.drop_index("ix_agent_packages_status", table_name="agent_packages")
    op.drop_table("agent_packages")
    bind = op.get_bind()
    sa.Enum("DRAFT", "ACTIVE", "ARCHIVED", name="agent_package_status").drop(
        bind,
        checkfirst=True,
    )

#!/usr/bin/env python3
"""Initialize default tenant and admin user in the database."""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from decimal import Decimal
from pathlib import Path
from typing import Optional
from uuid import uuid4

import bcrypt

from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

PROJECT_ROOT = Path(__file__).resolve().parents[1]
NOVA_SERVER_ROOT = PROJECT_ROOT / "NovaServer"
if str(NOVA_SERVER_ROOT) not in sys.path:
    sys.path.insert(0, str(NOVA_SERVER_ROOT))

from app.models.tenant import Tenant, TenantBalance, TenantStatus  # noqa: E402
from app.models.user import User, UserRole, UserStatus  # noqa: E402


async def ensure_tenant(session, name: str, tenant_id: Optional[str]) -> Tenant:
    result = await session.execute(select(Tenant).where(Tenant.name == name))
    tenant = result.scalar_one_or_none()
    if tenant:
        return tenant

    tenant = Tenant(id=tenant_id or str(uuid4()), name=name, status=TenantStatus.ACTIVE)
    session.add(tenant)
    session.add(
        TenantBalance(
            tenant_id=tenant.id,
            balance=Decimal("0"),
            frozen=Decimal("0"),
        )
    )
    await session.flush()
    return tenant


async def ensure_user(session, tenant: Tenant, username: str, password: str, user_id: Optional[str]) -> User:
    result = await session.execute(select(User).where(User.username == username))
    user = result.scalar_one_or_none()
    if user:
        return user

    hashed = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    user = User(
        id=user_id or str(uuid4()),
        tenant_id=tenant.id,
        username=username,
        password_hash=hashed,
        role=UserRole.ADMIN,
        status=UserStatus.ACTIVE,
    )
    session.add(user)
    await session.flush()
    return user


async def main() -> None:
    parser = argparse.ArgumentParser(description="Initialize default tenant/admin user")
    parser.add_argument(
        "--database-url",
        default=os.environ.get("NOVASERVER_DATABASE_URL", "postgresql+asyncpg://nova:nova@localhost:5432/nova"),
    )
    parser.add_argument("--tenant-name", default="Demo Tenant")
    parser.add_argument("--tenant-id", default=None)
    parser.add_argument("--username", default="demo")
    parser.add_argument("--password", default="demo123")
    parser.add_argument("--user-id", default=None)
    args = parser.parse_args()

    engine = create_async_engine(args.database_url, future=True)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)

    async with session_factory() as session:
        tenant = await ensure_tenant(session, args.tenant_name, args.tenant_id)
        user = await ensure_user(session, tenant, args.username, args.password, args.user_id)
        await session.commit()

    print("Tenant ID:", tenant.id)
    print("User ID:", user.id)
    print("Username:", user.username)


if __name__ == "__main__":
    asyncio.run(main())

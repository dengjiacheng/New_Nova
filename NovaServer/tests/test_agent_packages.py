import hashlib
import os
import shutil
from pathlib import Path

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
import sqlalchemy as sa

# 配置测试专用的 SQLite 数据库与存储目录
os.environ.setdefault("NOVASERVER_DATABASE_URL", "sqlite+aiosqlite:///./test_agent_packages.db")
os.environ.setdefault("NOVASERVER_AGENT_PACKAGE_STORAGE_DIR", "./test_storage/agent-packages")

from app.core.config import get_settings
from app.db.session import get_session_factory, get_engine
from app.main import app
from app.models import Base
from app.models.agent_package import AgentPackage


@pytest.fixture(autouse=True)
def _clean_storage() -> None:
    storage_dir = Path(get_settings().agent_package_storage_dir)
    if storage_dir.exists():
        shutil.rmtree(storage_dir)
    storage_dir.mkdir(parents=True, exist_ok=True)


@pytest_asyncio.fixture
async def auth_header() -> dict[str, str]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.post(
            "/api/auth/login",
            json={"username": "demo", "password": "demo123", "pcId": "PC-1"},
        )
    token = response.json()["data"]["token"]
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture(scope="session", autouse=True)
async def _setup_database() -> None:
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    db_path = Path("./test_agent_packages.db")
    if db_path.exists():
        db_path.unlink()
    storage_root = Path("./test_storage")
    if storage_root.exists():
        shutil.rmtree(storage_root)


@pytest_asyncio.fixture(autouse=True)
async def _truncate_agent_packages() -> None:
    session_factory = get_session_factory()
    async with session_factory() as session:
        await session.execute(sa.delete(AgentPackage))
        await session.commit()


@pytest.mark.asyncio
async def test_upload_and_activate_agent_package(auth_header: dict[str, str]) -> None:
    file_bytes = b"dummy-apk"
    checksum = "sha256:" + hashlib.sha256(file_bytes).hexdigest()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        upload_resp = await client.post(
            "/api/admin/agent-packages",
            headers=auth_header,
            files={
                "file": ("agent.apk", file_bytes, "application/vnd.android.package-archive"),
            },
            data={
                "versionName": "1.0.0",
                "versionCode": "1000",
                "releaseNotes": "first release",
                "checksum": checksum,
            },
        )

    assert upload_resp.status_code == 200
    payload = upload_resp.json()["data"]
    assert payload["versionName"] == "1.0.0"
    assert payload["status"] == "DRAFT"

    package_id = payload["packageId"]

    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        list_resp = await client.get("/api/admin/agent-packages", headers=auth_header)
    assert list_resp.status_code == 200
    items = list_resp.json()["data"]["items"]
    assert any(item["packageId"] == package_id for item in items)

    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        activate_resp = await client.post(
            f"/api/admin/agent-packages/{package_id}/activate", headers=auth_header
        )
    assert activate_resp.status_code == 200

    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        latest_resp = await client.get("/api/agent-packages/latest")
    assert latest_resp.status_code == 200
    latest = latest_resp.json()["data"]
    assert latest["packageId"] == package_id
    assert latest["status"] == "ACTIVE"

    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        download_resp = await client.get(
            f"/api/admin/agent-packages/{package_id}/download", headers=auth_header
        )
    assert download_resp.status_code == 200
    assert download_resp.content == file_bytes

    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        delete_resp = await client.delete(
            f"/api/admin/agent-packages/{package_id}", headers=auth_header
        )
    assert delete_resp.status_code == 200

    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        latest_after_delete = await client.get("/api/agent-packages/latest")
    assert latest_after_delete.status_code == 404

    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        download_after_delete = await client.get(
            f"/api/admin/agent-packages/{package_id}/download", headers=auth_header
        )
    assert download_after_delete.status_code == 404

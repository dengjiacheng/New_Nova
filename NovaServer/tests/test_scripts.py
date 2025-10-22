import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.config import get_settings
from app.core.container import build_service_container
from app.main import app


@pytest.fixture(autouse=True)
def _reset_scripts() -> None:
    settings = get_settings()
    container = build_service_container(settings)
    app.state.container = container
    yield
    container.billing_ledger.reset()
    container.execution_repository.reset()


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


@pytest.mark.asyncio
async def test_list_scripts_includes_purchase_flag(auth_header: dict[str, str]) -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/api/scripts", headers=auth_header)

    assert response.status_code == 200
    payload = response.json()["data"]
    scripts = payload["scripts"]
    assert len(scripts) >= 2
    first = scripts[0]
    assert "purchasePrice" in first
    assert first["purchased"] is False


@pytest.mark.asyncio
async def test_purchase_script_updates_balance_and_lists(auth_header: dict[str, str]) -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        purchase_resp = await client.post(
            "/api/scripts/SCRIPT_LOGIN/purchase",
            json={"pcId": "PC-1"},
            headers=auth_header,
        )
        assert purchase_resp.status_code == 200
        balance = purchase_resp.json()["data"]["balance"]
        assert balance == pytest.approx(801.0)

        purchased_resp = await client.get("/api/scripts/purchased", headers=auth_header)
        purchased_list = purchased_resp.json()["data"]["purchases"]
        assert any(item["scriptId"] == "SCRIPT_LOGIN" for item in purchased_list)

        scripts_resp = await client.get("/api/scripts", headers=auth_header)
        scripts = scripts_resp.json()["data"]["scripts"]
        login_entry = next(item for item in scripts if item["id"] == "SCRIPT_LOGIN")
        assert login_entry["purchased"] is True

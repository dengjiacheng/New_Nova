from decimal import Decimal

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.config import get_settings
from app.core.container import build_service_container
from app.main import app


@pytest.fixture(autouse=True)
def _reset_state() -> None:
    settings = get_settings()
    container = build_service_container(settings)
    app.state.container = container
    yield
    container.execution_repository.reset()
    container.billing_ledger.reset()


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


@pytest_asyncio.fixture
async def purchased_script(auth_header: dict[str, str]) -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        await client.post(
            "/api/scripts/SCRIPT_LOGIN/purchase",
            json={"pcId": "PC-1"},
            headers=auth_header,
        )


@pytest.mark.asyncio
async def test_create_execution_success(auth_header: dict[str, str], purchased_script: None) -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.post(
            "/api/executions",
            json={
                "pcId": "PC-1",
                "requests": [
                    {
                        "deviceId": "emulator-5554",
                        "scriptId": "SCRIPT_LOGIN",
                        "scriptVersion": "1.2.0",
                        "parameters": {"username": "demo"},
                    }
                ],
            },
            headers=auth_header,
        )

    assert response.status_code == 200
    item = response.json()["data"]["executions"][0]
    assert item["status"] == "QUEUED"
    assert item["charged"] == pytest.approx(2.0)
    assert item["balance"] == pytest.approx(799.0)


@pytest.mark.asyncio
async def test_create_execution_requires_purchase(auth_header: dict[str, str]) -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.post(
            "/api/executions",
            json={
                "pcId": "PC-1",
                "requests": [
                    {
                        "deviceId": "emulator-5554",
                        "scriptId": "SCRIPT_LOGIN",
                        "scriptVersion": "1.2.0",
                        "parameters": {},
                    }
                ],
            },
            headers=auth_header,
        )

    assert response.status_code == 400
    assert response.json()["detail"] == "SCRIPT_NOT_PURCHASED"


@pytest.mark.asyncio
async def test_create_execution_fails_when_balance_insufficient(
    auth_header: dict[str, str], purchased_script: None
) -> None:
    # 将余额削减至不足以支付执行费用
    ledger = app.state.container.billing_ledger
    ledger.deduct("TEN-DEMO", Decimal("799"))  # 购买后余额为 801，扣除 799 -> 剩余 2
    ledger.deduct("TEN-DEMO", Decimal("1.5"))  # 剩余 0.5, 不足以支付执行费 2

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.post(
            "/api/executions",
            json={
                "pcId": "PC-1",
                "requests": [
                    {
                        "deviceId": "emulator-5554",
                        "scriptId": "SCRIPT_LOGIN",
                        "scriptVersion": "1.2.0",
                        "parameters": {},
                    }
                ],
            },
            headers=auth_header,
        )

    assert response.status_code == 400
    assert response.json()["detail"] == "INSUFFICIENT_BALANCE"


@pytest.mark.asyncio
async def test_list_executions_returns_records(
    auth_header: dict[str, str], purchased_script: None
) -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        await client.post(
            "/api/executions",
            json={
                "pcId": "PC-1",
                "requests": [
                    {
                        "deviceId": "device-1",
                        "scriptId": "SCRIPT_LOGIN",
                        "scriptVersion": "1.2.0",
                        "parameters": {},
                    }
                ],
            },
            headers=auth_header,
        )

        list_response = await client.get("/api/executions", headers=auth_header)

    assert list_response.status_code == 200
    records = list_response.json()["data"]["records"]
    assert len(records) >= 1
    assert records[0]["status"] == "QUEUED"


@pytest.mark.asyncio
async def test_create_execution_version_mismatch(
    auth_header: dict[str, str], purchased_script: None
) -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.post(
            "/api/executions",
            json={
                "pcId": "PC-1",
                "requests": [
                    {
                        "deviceId": "emulator-5554",
                        "scriptId": "SCRIPT_LOGIN",
                        "scriptVersion": "9.9.9",
                        "parameters": {},
                    }
                ],
            },
            headers=auth_header,
        )

    assert response.status_code == 400
    assert response.json()["detail"] == "SCRIPT_VERSION_MISMATCH"

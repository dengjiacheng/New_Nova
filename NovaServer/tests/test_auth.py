import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.asyncio
async def test_login_success() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.post(
            "/api/auth/login",
            json={"username": "demo", "password": "demo123", "pcId": "PC-1"},
        )

    assert response.status_code == 200
    payload = response.json()
    assert payload["code"] == "OK"
    data = payload["data"]
    assert "token" in data and "refreshToken" in data
    assert data["user"]["roles"] == ["ADMIN"]


@pytest.mark.asyncio
async def test_login_failure_wrong_password() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.post(
            "/api/auth/login",
            json={"username": "demo", "password": "wrong", "pcId": "PC-1"},
        )

    assert response.status_code == 401
    assert response.json()["detail"] == "AUTH_FAILED"


@pytest.mark.asyncio
async def test_refresh_returns_new_token() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        login_response = await client.post(
            "/api/auth/login",
            json={"username": "demo", "password": "demo123", "pcId": "PC-1"},
        )
        refresh_token = login_response.json()["data"]["refreshToken"]

        refresh_response = await client.post(
            "/api/auth/refresh",
            json={"refreshToken": refresh_token},
        )

    assert refresh_response.status_code == 200
    payload = refresh_response.json()
    assert payload["code"] == "OK"
    assert "token" in payload["data"]


@pytest.mark.asyncio
async def test_logout_returns_ok() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.post("/api/auth/logout")

    assert response.status_code == 200
    assert response.json()["code"] == "OK"

import pytest
from starlette.testclient import TestClient

from app.main import app


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def test_pc_websocket_receives_execution_event(client: TestClient) -> None:
    login_resp = client.post(
        "/api/auth/login",
        json={"username": "demo", "password": "demo123", "pcId": "PC-1"},
    )
    token = login_resp.json()["data"]["token"]
    headers = {"Authorization": f"Bearer {token}"}

    client.post(
        "/api/scripts/SCRIPT_LOGIN/purchase",
        json={"pcId": "PC-1"},
        headers=headers,
    )

    with client.websocket_connect(f"/ws/pc?token={token}&pcId=PC-1") as ws:
        connected = ws.receive_json()
        assert connected["payload"]["event"] == "CONNECTED"

        create_resp = client.post(
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
            headers=headers,
        )
        assert create_resp.status_code == 200

        message = ws.receive_json()
        assert message["topic"] == "executions.progress"
        assert message["payload"]["status"] == "QUEUED"

"""PC 端 WebSocket 通道。"""

from __future__ import annotations

import json
from typing import Awaitable, Callable, Optional

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect

from app.api.dependencies import get_app_settings
from app.core.config import Settings
from app.core.container import ServiceContainer
from app.core.security import decode_jwt_token
from app.services.pubsub import PubSubBus

router = APIRouter()


@router.websocket("/pc")
async def pc_gateway(websocket: WebSocket, settings: Settings = Depends(get_app_settings)):
    token = websocket.query_params.get("token")
    pc_id = websocket.query_params.get("pcId")
    if not token or not pc_id:
        await websocket.close(code=4401)
        return

    try:
        payload = decode_jwt_token(settings, token)
    except Exception:
        await websocket.close(code=4401)
        return

    tenant_id = payload.get("tenantId")
    if not tenant_id:
        await websocket.close(code=4401)
        return

    tenant_key = f"tenant:{tenant_id}"
    await websocket.accept()

    container: Optional[ServiceContainer] = getattr(websocket.app.state, "container", None)
    if container is None:
        await websocket.close(code=1011)
        return

    bus: PubSubBus = container.event_bus

    async def subscriber(message: dict) -> None:
        await websocket.send_json(message)

    bus.subscribe(tenant_key, subscriber)
    await websocket.send_json(
        {
            "type": "EVENT",
            "topic": "system.notice",
            "payload": {"event": "CONNECTED", "pcId": pc_id},
        }
    )

    try:
        while True:
            data = await websocket.receive_json()
            # 简化处理：当前仅支持 subscribe 过滤，未实现过滤逻辑
            if data.get("topic") == "system.subscribe":
                await websocket.send_json(
                    {
                        "type": "REPLY",
                        "topic": "system.subscribe",
                        "payload": {"status": "ACK"},
                    }
                )
    except WebSocketDisconnect:
        pass
    finally:
        bus.remove(tenant_key, subscriber)
        await websocket.close()

"""Agent WebSocket 通道。"""

from __future__ import annotations

import json
from typing import Optional

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.container import ServiceContainer
from app.services.executions_dispatcher import ExecutionDispatcher

router = APIRouter()


@router.websocket("/agent")
async def agent_gateway(websocket: WebSocket):
    await websocket.accept()

    container: Optional[ServiceContainer] = getattr(websocket.app.state, "container", None)
    if container is None:
        await websocket.close(code=1011)
        return

    dispatcher: ExecutionDispatcher = container.dispatcher
    device_id: Optional[str] = websocket.query_params.get("deviceId")

    try:
        while True:
            message = await websocket.receive_json()
            msg_type = message.get("type")
            payload = message.get("payload", {})

            if msg_type == "EVENT" and payload.get("event") == "REGISTER":
                device_id = payload.get("deviceId")
                await websocket.send_json({
                    "version": "1.0",
                    "type": "REPLY",
                    "topic": "agents.status",
                    "payload": {"event": "ACK_REGISTER"},
                })
                if device_id:
                    task = dispatcher.next_task(device_id)
                    if task:
                        await websocket.send_json(
                            {
                                "version": "1.0",
                                "type": "COMMAND",
                                "topic": "executions.command",
                                "payload": {
                                    "command": "EXECUTE",
                                    "executionId": task.execution_id,
                                    "script": {
                                        "id": task.payload.get("scriptId"),
                                    },
                                    "parameters": task.payload.get("parameters", {}),
                                },
                            }
                        )
            elif msg_type == "EVENT" and payload.get("event") == "HEARTBEAT":
                await websocket.send_json(
                    {
                        "version": "1.0",
                        "type": "REPLY",
                        "topic": "agents.status",
                        "payload": {"event": "ACK_HEARTBEAT"},
                    }
                )
            elif msg_type == "REPLY" and payload.get("event") == "ACK_EXECUTE":
                # 未来可在此更新执行状态
                pass
    except WebSocketDisconnect:
        if device_id:
            dispatcher.complete_task(device_id)
        await websocket.close()

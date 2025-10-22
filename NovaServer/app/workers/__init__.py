"""后台任务管理。"""

from __future__ import annotations

import asyncio
from typing import Awaitable, Callable, Optional

from loguru import logger

from app.core.container import ServiceContainer


class WorkerManager:
    def __init__(self) -> None:
        self._tasks: list[asyncio.Task] = []
        self._running = False
        self._container: Optional[ServiceContainer] = None

    async def start(self, container: ServiceContainer) -> None:
        if self._running:
            return
        self._container = container
        self._running = True
        self._tasks.append(asyncio.create_task(self._execution_dispatch_loop()))

    async def stop(self) -> None:
        self._running = False
        for task in self._tasks:
            task.cancel()
        self._tasks.clear()
        self._container = None

    async def _execution_dispatch_loop(self) -> None:
        if self._container is None:
            logger.warning("WorkerManager started without container")
            return

        dispatcher = self._container.dispatcher
        bus = self._container.event_bus

        while self._running:
            await asyncio.sleep(0.1)
            # 占位实现：实际应遍历在线设备
            # 这里仅为结构示例，不做实际派发
            continue


manager = WorkerManager()

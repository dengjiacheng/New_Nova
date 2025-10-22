"""执行任务调度占位实现。"""

from __future__ import annotations

from collections import defaultdict, deque
from dataclasses import dataclass
from typing import Deque, Dict, Optional


@dataclass
class DispatchTask:
    execution_id: str
    tenant_id: str
    device_id: str
    payload: dict


class ExecutionDispatcher:
    """内存队列调度器，按设备串行派发任务。"""

    def __init__(self) -> None:
        self._queues: Dict[str, Deque[DispatchTask]] = defaultdict(deque)
        self._active: Dict[str, DispatchTask] = {}

    def enqueue(self, device_key: str, task: DispatchTask) -> None:
        self._queues[device_key].append(task)

    def next_task(self, device_key: str) -> Optional[DispatchTask]:
        if device_key in self._active:
            return None
        queue = self._queues.get(device_key)
        if not queue:
            return None
        task = queue.popleft()
        self._active[device_key] = task
        return task

    def complete_task(self, device_key: str) -> None:
        self._active.pop(device_key, None)

    def reset(self) -> None:
        self._queues.clear()
        self._active.clear()

"""简单的内存发布订阅，用于 PC 通知。"""

from __future__ import annotations

from collections import defaultdict
from typing import Awaitable, Callable, Dict, List

Subscriber = Callable[[dict], Awaitable[None]]


class PubSubBus:
    def __init__(self) -> None:
        self._subscribers: Dict[str, List[Subscriber]] = defaultdict(list)

    def subscribe(self, tenant_key: str, subscriber: Subscriber) -> None:
        self._subscribers[tenant_key].append(subscriber)

    async def publish(self, tenant_key: str, message: dict) -> None:
        for subscriber in list(self._subscribers.get(tenant_key, [])):
            await subscriber(message)

    def remove(self, tenant_key: str, subscriber: Subscriber) -> None:
        subs = self._subscribers.get(tenant_key)
        if not subs:
            return
        try:
            subs.remove(subscriber)
        except ValueError:
            pass

    def reset(self) -> None:
        self._subscribers.clear()

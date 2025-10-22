"""用户仓储接口定义。"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional


@dataclass
class UserRecord:
    id: str
    tenant_id: str
    username: str
    password_hash: str
    roles: list[str]


class UserRepository(ABC):
    """定义用户数据访问接口，后续可替换为数据库实现。"""

    @abstractmethod
    async def get_by_username(self, username: str) -> Optional[UserRecord]:
        raise NotImplementedError


class InMemoryUserRepository(UserRepository):
    """临时的内存实现，便于在无数据库阶段完成认证流程。"""

    def __init__(self, users: Optional[list[UserRecord]] = None) -> None:
        self._users = {user.username: user for user in users or []}

    async def get_by_username(self, username: str) -> Optional[UserRecord]:
        return self._users.get(username)

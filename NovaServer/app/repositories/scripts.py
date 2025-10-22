"""脚本仓储接口定义与内存实现。"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Dict, Iterable, List, Optional


@dataclass
class ScriptRecord:
    id: str
    name: str
    version: str
    description: Optional[str]
    purchase_price: Decimal
    execution_price: Decimal
    capabilities: Dict[str, Any]


@dataclass
class ScriptPurchaseRecord:
    tenant_id: str
    user_id: str
    script_id: str
    script_version: str
    price: Decimal
    purchased_at: datetime
    pc_id: Optional[str] = None


class ScriptRepository:
    async def list_scripts(self) -> List[ScriptRecord]:
        raise NotImplementedError

    async def get_script(self, script_id: str) -> Optional[ScriptRecord]:
        raise NotImplementedError

    async def list_purchases(self, tenant_id: str) -> List[ScriptPurchaseRecord]:
        raise NotImplementedError

    async def has_purchase(self, tenant_id: str, script_id: str) -> bool:
        raise NotImplementedError

    async def add_purchase(self, record: ScriptPurchaseRecord) -> None:
        raise NotImplementedError


class InMemoryScriptRepository(ScriptRepository):
    """开发阶段的内存实现。"""

    def __init__(self, scripts: Iterable[ScriptRecord]) -> None:
        self._scripts = {script.id: script for script in scripts}
        self._purchases: dict[str, dict[str, ScriptPurchaseRecord]] = {}

    async def list_scripts(self) -> List[ScriptRecord]:
        return list(self._scripts.values())

    async def get_script(self, script_id: str) -> Optional[ScriptRecord]:
        return self._scripts.get(script_id)

    async def list_purchases(self, tenant_id: str) -> List[ScriptPurchaseRecord]:
        return list(self._purchases.get(tenant_id, {}).values())

    async def has_purchase(self, tenant_id: str, script_id: str) -> bool:
        return script_id in self._purchases.get(tenant_id, {})

    async def add_purchase(self, record: ScriptPurchaseRecord) -> None:
        self._purchases.setdefault(record.tenant_id, {})[record.script_id] = record

    async def reset(self) -> None:
        self._purchases.clear()

    @staticmethod
    def demo_records() -> List[ScriptRecord]:
        return [
            ScriptRecord(
                id="SCRIPT_LOGIN",
                name="登录脚本",
                version="1.2.0",
                description="常见账号密码登录流程校验。",
                purchase_price=Decimal("199.00"),
                execution_price=Decimal("2.00"),
                capabilities={"requiresOpenCv": False},
            ),
            ScriptRecord(
                id="SCRIPT_CHECKOUT",
                name="下单脚本",
                version="1.0.5",
                description="完成商品下单与支付校验。",
                purchase_price=Decimal("299.00"),
                execution_price=Decimal("3.50"),
                capabilities={"requiresOpenCv": True},
            ),
        ]

    async def seed_demo_data(self) -> None:
        """确保演示脚本存在，可在测试中重置。"""

        self._scripts = {record.id: record for record in self.demo_records()}
        self._purchases.clear()


def build_demo_repository() -> InMemoryScriptRepository:
    repo = InMemoryScriptRepository(InMemoryScriptRepository.demo_records())
    return repo

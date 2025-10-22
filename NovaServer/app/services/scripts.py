"""脚本目录与购买服务。"""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from typing import List, Optional

from fastapi import HTTPException, status

from app.core.config import Settings
from app.repositories.scripts import (
    InMemoryScriptRepository,
    ScriptPurchaseRecord,
    ScriptRecord,
    ScriptRepository,
)
from app.schemas.scripts import (
    PurchasedScriptItem,
    PurchasedScriptsResponse,
    ScriptListItem,
    ScriptListResponse,
    ScriptPurchaseResponse,
)
from app.services.billing import BillingLedger, InsufficientBalance


class ScriptService:
    def __init__(
        self,
        settings: Settings,
        repository: ScriptRepository,
        ledger: Optional[BillingLedger] = None,
    ) -> None:
        self._settings = settings
        self._repository = repository
        self._ledger = ledger or BillingLedger(Decimal(str(settings.demo_initial_balance)))

    async def list_scripts(self, tenant_id: str) -> ScriptListResponse:
        scripts = await self._repository.list_scripts()
        purchases = await self._repository.list_purchases(tenant_id)
        purchased_ids = {purchase.script_id for purchase in purchases}

        items: List[ScriptListItem] = [
            self._build_script_item(script, script.id in purchased_ids)
            for script in scripts
        ]
        return ScriptListResponse(scripts=items)

    async def list_purchased_scripts(self, tenant_id: str) -> PurchasedScriptsResponse:
        purchases = await self._repository.list_purchases(tenant_id)
        items = [
            PurchasedScriptItem(
                script_id=purchase.script_id,
                script_version=purchase.script_version,
                price=float(purchase.price),
                purchased_at=purchase.purchased_at,
            )
            for purchase in sorted(
                purchases, key=lambda record: record.purchased_at, reverse=True
            )
        ]
        return PurchasedScriptsResponse(purchases=items)

    async def purchase_script(
        self,
        tenant_id: str,
        user_id: str,
        script_id: str,
        pc_id: Optional[str],
        ) -> ScriptPurchaseResponse:
        script = await self._repository.get_script(script_id)
        if not script:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="SCRIPT_NOT_FOUND",
            )

        if await self._repository.has_purchase(tenant_id, script_id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="SCRIPT_ALREADY_PURCHASED",
            )

        price = script.purchase_price
        try:
            new_balance = self._ledger.deduct(tenant_id, price)
        except InsufficientBalance as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="INSUFFICIENT_BALANCE",
            ) from exc

        record = ScriptPurchaseRecord(
            tenant_id=tenant_id,
            user_id=user_id,
            script_id=script.id,
            script_version=script.version,
            price=price,
            purchased_at=datetime.now(timezone.utc),
            pc_id=pc_id,
        )
        await self._repository.add_purchase(record)

        return ScriptPurchaseResponse(balance=float(new_balance))

    async def get_script(self, script_id: str) -> Optional[ScriptRecord]:
        return await self._repository.get_script(script_id)

    async def has_purchase(self, tenant_id: str, script_id: str) -> bool:
        return await self._repository.has_purchase(tenant_id, script_id)

    def get_balance(self, tenant_id: str) -> float:
        balance = self._ledger.get_balance(tenant_id)
        return float(balance)

    def reset_state(self) -> None:
        """测试或演示环境下重置余额与购买记录。"""
        self._ledger.reset()

    @staticmethod
    def _build_script_item(
        script: ScriptRecord, purchased: bool
    ) -> ScriptListItem:
        return ScriptListItem(
            id=script.id,
            name=script.name,
            description=script.description,
            version=script.version,
            purchase_price=float(script.purchase_price),
            execution_price=float(script.execution_price),
            capabilities=script.capabilities,
            purchased=purchased,
        )

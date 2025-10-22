"""简单的账务余额管理（内存实现）。"""

from __future__ import annotations

from collections import defaultdict
from decimal import Decimal
from typing import Dict


class BillingError(Exception):
    """账务异常，用于统一处理余额扣减错误。"""


class InsufficientBalance(BillingError):
    pass


class BillingLedger:
    """维护各租户余额的内存账本。"""

    def __init__(self, initial_balance: Decimal) -> None:
        self._initial = initial_balance
        self._balances: Dict[str, Decimal] = defaultdict(lambda: Decimal(self._initial))

    def get_balance(self, tenant_id: str) -> Decimal:
        return self._balances[tenant_id]

    def ensure_balance(self, tenant_id: str) -> None:
        # 访问时即保证默认余额创建
        _ = self._balances[tenant_id]

    def deduct(self, tenant_id: str, amount: Decimal) -> Decimal:
        if amount < 0:
            raise ValueError("amount must be positive")
        current = self._balances[tenant_id]
        if current < amount:
            raise InsufficientBalance(f"Tenant {tenant_id} balance insufficient")
        new_balance = current - amount
        self._balances[tenant_id] = new_balance
        return new_balance

    def reset(self) -> None:
        self._balances.clear()

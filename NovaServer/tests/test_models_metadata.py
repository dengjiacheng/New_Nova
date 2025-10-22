import pytest

import app.models  # noqa: F401  # 触发模型注册
from app.db.base import Base


@pytest.mark.parametrize(
    "table_name",
    [
        "tenants",
        "tenant_balances",
        "users",
        "scripts",
        "script_purchases",
        "executions",
        "execution_events",
        "transactions",
        "execution_assets",
        "audit_logs",
    ],
)
def test_metadata_contains_core_tables(table_name: str) -> None:
    assert table_name in Base.metadata.tables

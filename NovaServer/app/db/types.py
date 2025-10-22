"""数据库类型兼容层。"""

from __future__ import annotations

from sqlalchemy import JSON
from sqlalchemy.dialects.postgresql import JSONB

# 兼容 SQLite 测试环境，使用 JSON 作为变体
JSONB_COMPAT = JSONB().with_variant(JSON(), "sqlite")

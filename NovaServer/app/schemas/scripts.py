"""脚本相关 Pydantic 模型。"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class ScriptListItem(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    version: str = Field(alias="version")
    purchase_price: float = Field(alias="purchasePrice")
    execution_price: float = Field(alias="executionPrice")
    capabilities: Dict[str, Any] = Field(default_factory=dict)
    purchased: bool = False

    model_config = {
        "populate_by_name": True,
    }


class ScriptListResponse(BaseModel):
    scripts: List[ScriptListItem]

    model_config = {
        "populate_by_name": True,
    }


class ScriptPurchaseRequest(BaseModel):
    pc_id: Optional[str] = Field(default=None, alias="pcId")

    model_config = {
        "populate_by_name": True,
    }


class ScriptPurchaseResponse(BaseModel):
    balance: float


class PurchasedScriptItem(BaseModel):
    script_id: str = Field(alias="scriptId")
    script_version: str = Field(alias="scriptVersion")
    price: float
    purchased_at: datetime = Field(alias="purchasedAt")

    model_config = {
        "populate_by_name": True,
    }


class PurchasedScriptsResponse(BaseModel):
    purchases: List[PurchasedScriptItem]

    model_config = {
        "populate_by_name": True,
    }

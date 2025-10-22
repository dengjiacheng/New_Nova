"""执行任务相关模型。"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class ExecutionRequestItem(BaseModel):
    device_id: str = Field(alias="deviceId")
    script_id: str = Field(alias="scriptId")
    script_version: str = Field(alias="scriptVersion")
    parameters: Dict[str, Any] = Field(default_factory=dict)
    template_meta: Optional[Dict[str, Any]] = Field(default=None, alias="templateMeta")
    assets: List[Dict[str, Any]] = Field(default_factory=list)
    options: Optional[Dict[str, Any]] = None

    model_config = {"populate_by_name": True}


class ExecutionCreateRequest(BaseModel):
    pc_id: str = Field(alias="pcId")
    requests: List[ExecutionRequestItem]

    model_config = {"populate_by_name": True}


class ExecutionItemResponse(BaseModel):
    execution_id: str = Field(alias="executionId")
    device_id: str = Field(alias="deviceId")
    status: str
    charged: float
    balance: float

    model_config = {"populate_by_name": True}


class ExecutionCreateResponse(BaseModel):
    executions: List[ExecutionItemResponse]

    model_config = {"populate_by_name": True}


class ExecutionRecordResponse(BaseModel):
    execution_id: str = Field(alias="executionId")
    script_id: str = Field(alias="scriptId")
    device_id: str = Field(alias="deviceId")
    pc_id: str = Field(alias="pcId")
    status: str
    charged: float
    created_at: datetime = Field(alias="createdAt")
    parameters: Dict[str, Any] = Field(default_factory=dict)

    model_config = {"populate_by_name": True}


class ExecutionListResponse(BaseModel):
    records: List[ExecutionRecordResponse]

    model_config = {"populate_by_name": True}


class ExecutionListFilters(BaseModel):
    script_id: Optional[str] = Field(default=None, alias="scriptId")
    status: Optional[str] = None
    device_id: Optional[str] = Field(default=None, alias="deviceId")
    pc_id: Optional[str] = Field(default=None, alias="pcId")

    model_config = {"populate_by_name": True}

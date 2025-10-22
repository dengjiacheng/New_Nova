"""Agent 包管理相关 Schema 定义。"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, ConfigDict


class UploadedByInfo(BaseModel):
    id: str = Field(alias="id")
    name: Optional[str] = Field(default=None, alias="name")

    model_config = ConfigDict(populate_by_name=True)


class AgentPackageItem(BaseModel):
    package_id: str = Field(alias="packageId")
    version_name: str = Field(alias="versionName")
    version_code: int = Field(alias="versionCode")
    file_size: int = Field(alias="fileSize")
    checksum: str
    status: str = Field(alias="status")
    uploaded_at: datetime = Field(alias="uploadedAt")
    uploaded_by: UploadedByInfo = Field(alias="uploadedBy")
    download_url: Optional[str] = Field(default=None, alias="downloadUrl")
    release_notes: Optional[str] = Field(default=None, alias="releaseNotes")
    tenant_id: Optional[str] = Field(default=None, alias="tenantId")

    model_config = ConfigDict(populate_by_name=True)


class AgentPackageListResponse(BaseModel):
    items: list[AgentPackageItem]

    model_config = ConfigDict(populate_by_name=True)


class AgentPackageUploadResponse(AgentPackageItem):
    pass


class LatestAgentPackageResponse(AgentPackageItem):
    pass

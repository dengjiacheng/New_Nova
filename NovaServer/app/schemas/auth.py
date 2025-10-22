"""认证相关 Pydantic 模型。"""

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    username: str = Field(..., max_length=128)
    password: str = Field(..., max_length=256)
    pc_id: str = Field(..., alias="pcId", max_length=128)

    model_config = {"populate_by_name": True}


class LoginResponse(BaseModel):
    token: str
    refreshToken: str
    tenant: "TenantInfo"
    user: "UserInfo"
    balance: float


class RefreshRequest(BaseModel):
    refreshToken: str


class RefreshResponse(BaseModel):
    token: str


class TenantInfo(BaseModel):
    id: str
    name: str


class UserInfo(BaseModel):
    id: str
    roles: list[str]


LoginResponse.model_rebuild()

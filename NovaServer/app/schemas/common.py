"""通用响应模型。"""

from typing import Generic, Optional, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class ApiResponse(BaseModel, Generic[T]):
    code: str = "OK"
    message: Optional[str] = None
    data: T
    traceId: Optional[str] = None

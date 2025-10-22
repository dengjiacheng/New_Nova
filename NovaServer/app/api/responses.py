"""统一响应封装。"""

from typing import Any, Optional

from app.schemas.common import ApiResponse


def ok(data: Any, message: Optional[str] = None) -> dict[str, Any]:
    if hasattr(data, "model_dump"):
        prepared = data.model_dump(by_alias=True)  # type: ignore[attr-defined]
    else:
        prepared = data
    response = ApiResponse(code="OK", message=message, data=prepared)
    return response.model_dump(exclude_none=True)

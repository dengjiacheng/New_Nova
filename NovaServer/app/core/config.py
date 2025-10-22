"""应用配置定义。

配置需通过 `Settings` 注入业务逻辑，禁止在模块中直接读取环境变量。
"""

from functools import lru_cache
from typing import Literal, Union

from pydantic import Field, HttpUrl
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """全局配置，所有依赖通过 DI 获取实例。"""

    model_config = SettingsConfigDict(env_file=".env", env_prefix="NOVASERVER_")

    app_name: str = "NovaServer"
    environment: Literal["development", "staging", "production"] = "development"
    debug: bool = True

    api_prefix: str = "/api"
    websocket_prefix: str = "/ws"

    database_url: str = Field(
        default="postgresql+asyncpg://nova:nova@localhost:5432/nova",
        description="PostgreSQL 连接串，使用 SQLAlchemy Async Engine。",
    )
    redis_url: str = Field(
        default="redis://localhost:6379/0",
        description="用于在线设备状态、执行队列与发布订阅。",
    )

    agent_package_storage_dir: str = Field(
        default="storage/agent-packages",
        description="Agent APK 文件存储目录（相对项目根或绝对路径）。",
    )

    jwt_secret: str = Field(default="change-me", description="JWT 签名密钥。")
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60
    jwt_refresh_expire_minutes: int = 60 * 24 * 7

    demo_initial_balance: float = 1000.0

    agent_token_secret: str = Field(
        default="change-agent-token",
        description="Agent 连接 token 加密密钥。",
    )

    cors_allow_origins: Union[list[HttpUrl], Literal["*"]] = Field(
        default=["http://localhost:3000"], description="允许的跨域来源。"
    )

    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


@lru_cache
def get_settings() -> Settings:
    """返回缓存的配置实例。通过 Depends 注入，保证单例。"""

    return Settings()

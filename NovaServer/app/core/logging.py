"""日志初始化工具。"""

import logging

from .config import Settings


def init_logging(settings: Settings) -> None:
    """根据配置初始化根日志器。"""

    logging.basicConfig(
        level=settings.log_level,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    )

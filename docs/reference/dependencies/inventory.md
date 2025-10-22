---
title: 依赖清单（多端）
status: active
updated_at: 2025-10-22
dcp: TASK-20251022-1732-ONBRD
---

# 依赖清单

## 概览

| 模块 | 生态 | 依赖管理 | 备注 |
| ---- | ---- | -------- | ---- |
| NovaServer | Python 3.10+ | `pyproject.toml` / `pip` | FastAPI 异步后端 |
| NovaAgent | Android/Kotlin | Gradle Kotlin DSL | 包含核心库与应用模块 |
| NovaDesk | Flutter 3.3+ | `pubspec.yaml` | 多平台桌面 |
| Autopilot | Node.js 20+ | `package.json` | 守护脚本与自动化 |

## NovaServer（Python）

| 类型 | 包 | 版本/约束 | 用途 |
| ---- | ---- | -------- | ---- |
| runtime | fastapi | >=0.111.0 | Web API 框架 |
| runtime | uvicorn[standard] | >=0.30.0 | ASGI Server |
| runtime | pydantic / pydantic-settings | >=2.7.0 / >=2.2.1 | 配置与数据校验 |
| runtime | loguru | >=0.7.2 | 日志 |
| runtime | pyjwt | >=2.8.0 | JWT 认证 |
| runtime | passlib[bcrypt] | >=1.7.4 | 密码散列 |
| runtime | sqlalchemy[asyncio] | >=2.0.30 | ORM + 异步访问 |
| runtime | asyncpg | >=0.29.0 | PostgreSQL 驱动 |
| runtime | alembic | >=1.13.2 | 数据库迁移 |
| runtime | python-multipart | >=0.0.9 | 上传解析 |
| dev/test | httpx | >=0.27.0 | API/WS 测试 |
| dev/test | pytest | >=8.2.0 | 测试框架 |
| dev/test | pytest-asyncio | >=0.23.0 | 异步测试 |

## NovaAgent（Android/Kotlin）

> 依赖定义于 `NovaAgent/app/build.gradle.kts` 与 `NovaAgent/core/build.gradle.kts`。

| 模块 | 类型 | 库 | 版本 | 说明 |
| ---- | ---- | --- | ---- | ---- |
| core | api | kotlinx-coroutines-core | 1.7.3 | 协程核心 |
| core | api | moshi / moshi-kotlin | 1.15.0 | JSON 序列化 |
| core | api | okio | 3.6.0 | I/O |
| core | api | okhttp | 4.12.0 | 网络通信 |
| core | testImplementation | kotlin-test | 1.9.23 | 单元测试 |
| core | testImplementation | kotlinx-coroutines-test | 1.7.3 | 协程测试 |
| app | implementation | androidx.core:core-ktx | 1.13.1 | Android 基础 |
| app | implementation | androidx.lifecycle:lifecycle-runtime-ktx | 2.8.6 | 生命周期 |
| app | implementation | androidx.startup:startup-runtime | 1.1.1 | 初始化框架 |
| app | implementation | kotlinx-coroutines-android | 1.7.3 | 协程 |
| app | implementation | androidx.test:runner / monitor | 1.5.2 / 1.6.1 | 测试运行时 |
| app | implementation | okhttp / logging-interceptor | 4.12.0 | Agent 网络通信 |

## NovaDesk（Flutter）

| 类型 | 包 | 版本 | 用途 |
| ---- | --- | ---- | ---- |
| runtime | flutter | sdk | UI 框架 |
| runtime | path | ^1.9.0 | 路径处理 |
| runtime | uuid | ^4.4.0 | 标识生成 |
| runtime | flutter_riverpod | ^2.4.10 | 状态管理 |
| runtime | web_socket_channel | ^2.4.0 | WebSocket 访问 |
| runtime | meta / collection | ^1.12.0 / ^1.18.0 | Dart 基础增强 |
| runtime | dio | ^5.4.3 | HTTP 客户端 |
| runtime | file_picker | ^8.0.3 | 文件选择 |
| runtime | crypto | ^3.0.3 | 加密散列 |
| dev | flutter_test | sdk | 测试框架 |
| dev | flutter_lints | ^3.0.0 | 代码规范 |

## Autopilot/工具

| 类型 | 包 | 版本 | 说明 |
| ---- | --- | ---- | ---- |
| dev | chokidar | ^3.5.3 | 文件监听 |
| dev | js-yaml | ^4.1.0 | YAML 解析 |

## 依赖管理策略

1. 按季度固定窗口（建议每季度第一个迭代）统一升级次版本；
2. 建立 `scripts/dependency_audit` 任务，结合 `pip-audit`、`npm audit`、`gradle dependencyUpdates`；
3. 对跨端协议相关依赖（例如 OkHttp、web_socket_channel）保持兼容版本对齐；
4. 在 `docs/reference/dependencies/compatibility.md` 后续维护跨端兼容矩阵。

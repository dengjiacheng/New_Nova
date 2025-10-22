---
title: Nova 平台架构说明
status: active
updated_at: 2025-10-22
dcp: TASK-20251022-1732-ONBRD
---

# Nova 平台架构说明

## 架构分层

1. **体验层（NovaDesk）**：Flutter 桌面应用，负责运营操作、实时状态呈现与脚本配置。通过 REST/WebSocket 调用后端。
2. **执行层（NovaAgent）**：Android/Kotlin 组件，常驻终端设备，实现脚本执行、日志采集与状态上报。与 NovaServer 建立双向 websocket 管道，支持命令/事件模型。
3. **控制层（NovaServer）**：FastAPI 服务，承载 REST API、WebSocket 通道、任务调度与后台 worker。依赖 PostgreSQL（或等效数据库）持久化资产与执行记录。

## 核心组件

| 层 | 组件 | 描述 |
| --- | --- | --- |
| NovaServer | `app/core/config.py` | 统一配置，读取 `.env`/环境变量，注入依赖容器。 |
| NovaServer | `app/api/router.py` 与 `app/api/routers/*` | 定义 REST/WS 入口，按资源拆分。 |
| NovaServer | `app/services/executions/*` | 执行编排、状态机、结果处理。 |
| NovaServer | `app/workers/manager.py` | 启动后台 worker，处理异步任务。 |
| NovaAgent | `core/src/main/.../ws` | WebSocket 客户端、消息路由、序列化。 |
| NovaAgent | `core/src/main/.../execution` | 脚本执行编排，协调命令解析与结果汇聚。 |
| NovaDesk | `lib/application/*` | Riverpod 状态管理，包含连接、设备、模板等控制器。 |
| NovaDesk | `lib/platform/*` | 跨平台桥接层，封装桌面原生能力（文件、ADB 调用等）。 |

## 数据与控制流

1. **脚本下发**：NovaDesk 通过 REST 调度接口提交脚本 → NovaServer 记录执行计划，推送指令至 Agent WebSocket → NovaAgent 执行并回传结果 → NovaServer 更新状态并广播事件。
2. **设备同步**：Agent 周期性上报设备信息 → NovaServer 经 `repositories/device` 入库 → NovaDesk 拉取最新列表并缓存。
3. **资产管理**：NovaDesk 上传模板/脚本 → NovaServer 进入对象存储并更新索引 → Agent 请求时按策略拉取。

## 横切关注点

- **认证授权**：JWT（`app/core/security.py`）管理访问令牌；Agent 使用签名握手。
- **配置管理**：`pydantic-settings` 统一配置；Flutter/Android 使用 `.env`/BuildConfig 常量。
- **可观测性**：`loguru` 统一日志；待补充指标与 tracing。
- **错误恢复**：Agent `PersistentReporterQueue` 保证离线重试；Server Workers 实现补偿逻辑。

## 集成边界

- 外部系统（CI/CD、制品库）通过 REST API 与 Artifacts 目录交互。
- 终端资源（ADB、文件系统）由 NovaDesk/NovaAgent 通过本地桥接访问。
- 数据库/队列尚未完全实现，可根据部署需要接入 PostgreSQL、Redis。

## 改进建议

1. 引入统一消息契约（Proto/JSON Schema）并生成多端代码，减少手写解析。
2. 在 Server 引入领域事件总线，对接队列（如 RabbitMQ）以提升扩展性。
3. 将 NovaDesk 平台层拆分 Flutter 插件，降低平台代码与 UI 的耦合。
4. 补齐 Observability：接入 OpenTelemetry、Grafana 仪表板。

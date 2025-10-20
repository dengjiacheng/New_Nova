# NovaServer 架构概述

NovaServer 负责统一的用户认证、租户隔离、脚本授权与计费、设备在线管理、执行调度、审计与通知。采用 FastAPI + Uvicorn，配合 PostgreSQL 与 Redis。

## 模块划分

| 模块 | 说明 |
| --- | --- |
| `api.auth` | 登录、刷新、注销、超级管理员入口 |
| `api.tenants` | 租户管理（仅超级管理员）、租户配置查询 |
| `api.devices` | 在线设备列表（内存态）、设备状态查询 |
| `api.scripts` | 脚本目录、购买、授权校验 |
| `api.executions` | 执行任务提交、取消、历史查询 |
| `api.assets` | 执行附件上传、删除 |
| `api.billing` | 余额、充值、消费记录查询 |
| `ws.pc` | PC 客户端 WebSocket 接口（事件推送） |
| `ws.agent` | Agent WebSocket 接口（注册、心跳、执行指令） |
| `services.auth` | JWT、token 签发与校验 |
| `services.execution` | 执行状态机、设备队列、任务调度 |
| `services.billing` | 购买扣费、执行扣费、账单生成 |
| `services.audit` | 审计日志写入与归档 |
| `repositories.*` | SQLAlchemy repository，封装 ORM 操作 |
| `schemas` | Pydantic 模型定义（REST/WS Payload） |
| `workers` | 后台任务：队列调度、心跳检测、审计归档 |

## 框架与中间件

- **FastAPI**：REST API 与 WebSocket 共享事件循环。
- **SQLAlchemy 2.0**：声明式 ORM + Alembic 迁移。
- **Redis**：存储在线设备、执行队列、发布订阅（WS 通知）。
- **任务调度**：可使用 `asyncio` 背景任务或 Celery（取决于部署策略）。
- **日志与追踪**：结构化日志（JSON），traceId 注入，支持 OpenTelemetry 扩展。

## 关键设计

- 设备信息不持久化：`services.execution` 仅在 Redis/内存维护在线设备字典 `{ (tenantId, userId, pcId, deviceId) -> DeviceState }`。
- 执行队列：每个 `deviceKey` 拥有独立队列，保证单设备串行；队列消息包含执行请求与状态。
- 授权与扣费：在创建执行任务前先校验购买与余额；扣费成功后方可排队执行。
- 附件管理：执行任务支持附带临时资源，存储在对象存储并通过签名 URL 下发，后台任务定期清理。
- 多端登录：同账号多 PC 共享脚本、余额；事件推送按 `tenantId/userId` 广播，但 payload 含 `pcId` 便于客户端过滤。

## 配置项

- 数据库、Redis、JWT 秘钥、Agent token 密钥、审计保留期、归档周期、心跳间隔、任务超时。
- 管理后台默认超级管理员账号，通过环境变量或初始化脚本创建。

详细 API、数据模型、后台任务说明参见本目录其他文档。

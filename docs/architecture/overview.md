# Nova 平台总体架构

## 组件拓扑

- **NovaDesk（PC 桌面端）**：Flutter 桌面应用，负责用户登录、设备发现与 Agent 启动/停止、脚本模板管理、执行任务发起（含附件上传）与结果展示。单台物理 PC 仅允许运行一个 NovaDesk 实例，但同一账号可在多台 PC 并行登录。
- **NovaServer（云服务端）**：FastAPI + ASGI 技术栈，统一处理认证、多租户隔离、脚本授权与计费、设备在线状态、执行任务调度、审计日志与消费流水。
- **NovaAgent（Android 运行器）**：Instrumentation Runner（`AndroidJUnitRunner` 子类），内置脚本库；启动后主动连接 NovaServer WebSocket，等待调度并回报执行状态。
- **外部依赖**：PostgreSQL（租户、用户、交易）、Redis（会话状态、任务分发、心跳）、对象存储可选（审计归档）、Nginx（TLS 终止与反向代理）。

拓扑关系：`NovaDesk ⇄ NovaServer ⇄ NovaAgent`。PC 与 Agent 不直接通信，所有调度通过 Server 中转。

## 通信通道

| 通道 | 发起方 | 协议 | 用途 |
| --- | --- | --- | --- |
| PC → Server | REST (HTTPS) | 登录、脚本商城、模板执行、查询结果、余额与账单 |
| PC ↔ Server | WebSocket (WSS) | 执行进度、设备状态推送、通知 |
| Agent ↔ Server | WebSocket (WSS) | Agent 注册、心跳、执行指令、结果回传 |
| PC → 设备 | ADB (本地) | 安装/启动 Agent、传递启动参数（本地自管，不入审计） |

所有云端通信使用 JWT（PC）或 Device Token（Agent）进行鉴权，TLS 由 Nginx 终止。

## 标识体系

| 名称 | 说明 | 来源 |
| --- | --- | --- |
| `userId` | 云端账号唯一标识 | Server |
| `tenantId` | 多租户标识 | Server |
| `pcId` | PC 客户端实例 ID，首次登录生成并持久化（重装后重建） | NovaDesk |
| `deviceId` | 设备唯一标识（ADB serial/组合 SN） | NovaDesk 探测 |
| `agentId` | Agent 运行时标识，可等同于 `deviceId` | Agent 上报 |
| `scriptId` | 预置脚本标识 | Server 维护 |
| `templateId` | 本地模板标识，仅在 PC 内部使用 | NovaDesk |
| `executionId` | 单次脚本执行任务唯一标识 | Server |

执行请求中需包含 `tenantId`、`userId`（JWT 解出）、`pcId`、`deviceId`、`scriptId`、模板参数快照，Server 基于这些信息进行校验与调度。

## 生命周期概览

1. **登录阶段**：NovaDesk 使用账号密码（或后续 MFA）调用 Server 登录 API，获取 JWT 与租户信息，生成 `pcId` 并持久化。
2. **设备发现**：NovaDesk 周期性通过 ADB 列举本地设备，形成本地设备列表。
3. **Agent 启动**：用户点击“上线” → PC 通过 ADB 安装/启动 Agent，并写入 `authToken`、`serverUrl`、`pcId`、`deviceId` 等参数。
4. **Agent 注册**：Agent 与 Server 建立 WebSocket，注册设备并进入在线状态；Server 内存表记录 `(tenantId, userId, pcId, deviceId)`。
5. **脚本模板**：用户在 PC 端为某脚本创建模板，仅存本地，包含参数字段与默认值。
6. **任务发起**：用户选择脚本 + 模板 + 设备 → NovaDesk 调 Server REST API 生成执行任务。
7. **计费与调度**：Server 校验脚本购买授权，按执行次数扣费，排队并通过 WS 下发指令给对应 Agent（单设备串行）。
8. **执行回报**：Agent 执行内置脚本，持续发送进度、日志、最终结果，Server 转推给相关 PC。
9. **审计与消费记录**：Server 记录执行明细与扣费流水，热存储保存近 3~6 个月，定期归档至冷存储。
10. **下线与清理**：设备停止或断连 → Agent 心跳失效 → Server 删除在线记录，PC 列表同步为“下线”。

## 数据契约（概要）

- REST API 响应统一格式：`{ "code": "OK", "message": "...", "data": { ... } }`，错误码采用命名常量（如 `AUTH_FAILED`、`FEATURE_NOT_IMPLEMENTED`）。
- WebSocket 消息使用统一 envelope：`{ "version": "1.0", "type": "EVENT|COMMAND|REPLY", "topic": "...", "correlationId": "...", "payload": { ... } }`。
- 参数快照在执行请求中序列化为 JSON（由本地模板生成），Server 原样透传给 Agent，并在执行记录中冗余存档。

更细节的 API、消息字段定义见 `server/`、`agent/` 目录的对应文档。

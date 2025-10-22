# 核心流程说明

本文件对 Nova 平台关键业务流程的时序逻辑进行拆解，支持前后端、Agent 与运维团队的同步实现。

## 1. PC 登录与 `pcId` 初始化

NovaDesk 启动后会先通过互斥锁/进程检测确保本机仅有一个实例运行，若检测到已有实例则提示用户退出。

1. NovaDesk 启动 → 检查本地存储是否已有 `pcId`。
2. 若无，则生成新的 UUIDv4 并持久化在运行目录配置文件中。
3. 用户输入账号密码 → 调用 `POST /api/auth/login`。
4. Server 校验凭证，返回 JWT、租户信息、用户信息、可用余额等。
5. NovaDesk 缓存 JWT（内存 + 安全存储），所有后续请求与 WS 连接均携带。

> 若用户清空数据或重装客户端，会生成新的 `pcId`，Server 视为新的 PC 实例。

## 2. 设备发现与上线

1. NovaDesk 定时执行 `adb devices` 获取本地设备列表，解析为 `deviceId`（ADB serial 或指定规则）。
2. 本地列表可选择手动刷新；UI 以“上线/下线”状态展示（初始均为下线）。
3. 用户点击“上线” → 客户端执行：
   - 检查 `GET /api/agent-packages/latest` 返回的版本号，若高于当前本地缓存版本则提示管理员从 Admin Tools 下载并上传到本机缓存，再执行 `adb install`。
  - 通过 ADB 启动 Agent 主进程，并注入启动参数：`authToken`（Agent 专用）、`serverUrl`、`tenantId`、`userId`、`pcId`、`deviceId`。
4. Agent 启动后建立 WSS 连接 `wss://server/ws/agent`，发送 `REGISTER` 消息。
5. Server 验证 token → 在内存中登记设备在线信息，推送状态给该账号下所有在线 PC。
6. PC 收到状态变更事件，更新 UI 为“上线”；若用户点击“下线”，NovaDesk 通过 ADB `force-stop` 或调用 Server `stop` 接口停止 Agent，随后 Agent 主动断开；若心跳超时，Server 也会判定离线并删除记录。

## 2.1 WebSocket 事件分发管线

1. 登录成功后，NovaDesk 使用 JWT 建立 `wss://server/ws/pc` 连接（`PcWebSocketService`）。
2. 建连后发送 `HELLO` 帧，附带 `pcId`、`appVersion`、`capabilities`；Server 记录会话并返回 `ACK`（含心跳间隔等配置）。
3. 服务端推送的原始消息统一为：
   ```json
   {
     "topic": "agents.status",
     "traceId": "xxx",
     "payload": { ... }
   }
   ```
4. `PcWebSocketService` 将 JSON 解析为 `CoreEvent`，并根据 topic 分发至对应领域事件通道（如 `DeviceEventBus`）。
5. 应用层针对不同 topic 注册处理器（逐步拆分为特性模块）：
   - `DeviceEventBus` → `DeviceController` 更新 `deviceState`（订阅 `agents.status`）；
   - `ExecutionEventHandler` → 更新执行进度/结果（订阅 `executions.progress`、`executions.result`）；
   - `BillingEventHandler` → 更新余额、通知 UI（订阅 `system.notice` 等）；
   - 未识别的 topic 记录告警日志。
6. 事件处理器通过对应的状态 Controller（Riverpod Notifier/BLoC）提交状态更新，确保 UI 仅通过 Provider 读取。
7. 心跳：PC 侧按 `pingInterval` 定期发送 `PING`，Server 回复 `PONG`。若超时 3 次则尝试重连，重连成功后应拉取最近的执行/设备状态增量并补发事件。
8. 若 WS 连接异常关闭，`PcWebSocketService` 进入指数退避重连，并广播 `ConnectionStateEvent` 给 UI 显示“尝试重连”提示。

## 3. 脚本模板管理（本地）

1. NovaDesk 从脚本目录或 Server 脚本列表中展示可执行脚本。
2. 用户可基于脚本定义创建多个模板：字段名称、类型、默认值、描述。
3. 模板持久化在 `templates/<scriptId>/<templateName>.json`（建议结构化存储），与 `pcId` 无强绑定，供本机多账号使用。
4. 执行前可编辑模板字段，生成参数快照；模板只存本地，不上传 Server。
5. 支持导入/导出 JSON 文件，实现跨 PC 手动同步。

## 4. 脚本购买与授权

1. 用户在脚本商城选择脚本 → 调用 `POST /api/scripts/{scriptId}/purchase`。
2. Server 校验余额 → 扣取购买费用（一次性），记录交易流水。
3. 返回购买成功信息，客户端缓存状态；购买记录可通过 `GET /api/scripts/purchased` 查询。
4. 未购买的脚本无法发起执行。

## 5. 脚本执行（单设备串行，多设备并行）

1. 用户选择脚本 + 从 `TemplateRepository` 读取模板列表，并基于 schema 校验字段；若缺少必填字段则阻止执行。
2. 若模板包含文件字段，NovaDesk 通过 `ExecutionAssetService` 上传所需文件（`POST /api/executions/assets`），获取 `assetId` 与签名 URL；失败则终止流程并提示用户。
3. NovaDesk 为每台设备创建执行请求，内容包含：
   - `scriptId`、脚本版本；
   - 参数快照（JSON，对应模板字段）；
   - `pcId`、`deviceId`；
   - `tenantId`、`userId`（由 JWT 提供）。
4. 调用 `POST /api/executions` 批量创建任务，Server 对每个任务：
   - 校验脚本购买状态与可用余额；
   - 按执行费用扣费（设备数 × 单次费用，但逐任务扣费）；
   - 创建 `executionId`，状态置为 `QUEUED`。
5. Server 查找目标设备在线状态：
   - 若设备空闲 → 立即通过 WS 向 Agent 发送 `EXECUTE` 命令；
   - 若正在执行 → 将任务放入设备专属队列，等待 Agent 回报完成后继续。
6. Agent 收到指令后：
   - 验证脚本是否内置且版本匹配；
   - 若指令包含 `assets`，则按 `downloadUrl` 下载资源并解压到临时目录；
   - 按参数执行，周期性发送 `PROGRESS` 事件、异常日志。
7. Server 将事件转发给所有需要的 PC（默认同账号所有在线 PC）；NovaDesk 更新 UI。
8. 任务结束 → Agent 发送 `COMPLETE` 或 `FAILED`，附执行摘要与错误码。
9. Server 更新执行记录（含参数快照、结果、耗时），写入审计和消费流水。
10. NovaDesk 可通过轮询或 WS 接口获得最终状态，并支持查看历史记录。

## 6. 多端登录与并发控制

- 同账号可在多个 `pcId` 登录；Server 维护每个 `pcId` 的在线设备集合。
- 当同一设备被不同 PC 尝试上线：
  - Server 可选择以最新一次注册为准或返回冲突错误（策略后续确定）。
  - NovaDesk UI 应提示当前设备被其他 PC 占用。
- 执行锁：Server 对每个 `deviceId` 维护单一执行上下文，确保串行；队列中的任务按提交顺序执行。
- 通知：Server 可推送多端登录提醒、设备冲突、余额不足等事件。

## 7. 扣费与审计

- 扣费在任务创建时完成；若后续执行失败，是否退款可按策略配置（默认不退）。
- 审计日志仅覆盖脚本执行及消费记录：
  - 热数据（3~6 个月）存 PostgreSQL；
  - 冷数据按月导出压缩存储（对象存储/归档库）。
- 审计记录冗余必要字段：`executionId`、`scriptId`、`scriptVersion`、`pcId`、`deviceId`、参数快照摘要、扣费金额、结果、时间戳。

## 8. 异常处理

- Agent 断线：Server 标记设备离线，清理队列未执行任务（状态改为 `CANCELLED_DEVICE_OFFLINE`），通知相关 PC。
- PC 与 Server WS 断线：PC 需要在重连后重新订阅执行事件；任务不受影响。
- 扣费失败：返回错误 `INSUFFICIENT_BALANCE`，客户端提示用户充值。
- 脚本版本不匹配：Agent 返回 `SCRIPT_VERSION_MISMATCH`，Server 记录失败并提示 PC 更新 Agent 或脚本。

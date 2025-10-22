# WebSocket 交互（服务端视角）

NovaServer 暴露两个 WebSocket 端点：

- `wss://<host>/ws/pc`：PC 客户端连接，用于接收设备状态、执行进度、通知。
- `wss://<host>/ws/agent`：Agent 连接，用于注册、心跳、接受执行指令、回报结果。

## PC 通道

### 建连流程
1. PC 使用登录获得的 JWT 连接 `/ws/pc?token=<jwt>&pcId=<pcId>`.
2. Server 验证 token，有效则将连接加入订阅组：`(tenantId, userId)`。
3. Server 返回 `CONNECTED` 事件：
   ```json
   { "type": "EVENT", "topic": "system.notice", "payload": { "event": "CONNECTED" } }
   ```

### 订阅组策略
- 默认广播：同一账号的所有 PC 都接收 `agents.status`、`executions.*` 消息。
- 客户端可发送订阅指令，过滤只接收与自身 `pcId` 相关的消息：
  ```json
  {
    "type": "COMMAND",
    "topic": "system.subscribe",
    "payload": { "pcId": "PC-123", "filters": ["executions:*"] }
  }
  ```

### 推送内容
- 设备上线/下线：`agents.status`。
- 执行进度/结果：`executions.progress/result`。
- 消费通知/余额预警：`system.notice`。
- Agent 新版本通知：激活新 APK 后发送 `system.notice`，payload 包含 `event: "AGENT_PACKAGE_UPDATED"`, `versionName`, `versionCode`, `packageId`，PC 可据此提示管理员前往 Admin Tools 处理更新。
- 若连接断开，Server 会在日志中记录，客户端需按需重连。

## Agent 通道

### 建连与注册
1. Agent 启动后连接 `/ws/agent?token=<deviceToken>&pcId=<pcId>&deviceId=<deviceId>`.
2. Server 验证 token 后要求 Agent 发送 `REGISTER` 事件（见 `architecture/message_protocol.md`）。
3. Server 更新在线设备表、通知相关 PC。
4. 返回 `ACK_REGISTER` 回复。

### 心跳
- Agent 每 `heartbeatInterval` 秒发送 `HEARTBEAT`：
  ```json
  {
    "type": "EVENT",
    "topic": "agents.status",
    "payload": {
      "event": "HEARTBEAT",
      "deviceId": "emulator-5554",
      "pcId": "PC-123",
      "timestamp": "2024-06-01T12:00:30Z",
      "metrics": { "cpu": 0.12, "memory": 312 }
    }
  }
  ```
- 若超过 `heartbeatTimeout` 未收到心跳，Server 认为离线，触发下线流程。

### 执行指令
- Server 将执行请求写入容器中的 `ExecutionDispatcher`，选取设备队首任务，通过 WS 发送 `EXECUTE` 命令。派发 payload 会携带 `executionId`、`scriptId`、`scriptVersion`、`pcId`、`parameters` 等字段，便于 Agent 对齐契约。
- Agent 需立即回复 `ACK_EXECUTE` 表示已开始；否则任务重试或标记失败。
- 运行中按步骤发送进度，最终发送 `COMPLETE` 或 `FAILED`。

### 断线与恢复
- Agent 主动退出时发送 `DEREGISTER`。
- 异常断线：Server 在超时后处理为离线，清空其队列、标记运行中的任务失败。
- 重连时需重新发送 `REGISTER` 与脚本目录，Server 会从队列头重新下发未完成任务（状态可调为 `RETRYING`）。

## 可靠性考虑

- **消息持久化**：默认使用内存队列 `ExecutionDispatcher` 托管设备序列；若部署需要持久化，可替换为 Redis/其他实现而无需修改 WebSocket 层代码。
- **顺序保证**：同一 `deviceId` 的队列在 Server 端串行消费，避免并发执行。
- **背压**：若 PC 端未及时消费 WS 消息，Server 可根据配置断开连接并记录警告。
- **安全**：Agent token 与 JWT 需要独立管理；建议限制 Agent token 生命周期，结合设备白名单。

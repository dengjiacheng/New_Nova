# 运行生命周期

## 1. 启动

1. Runner 收到 `onStart` 回调，读取 `InstrumentationArguments`。
2. 构建 `AgentConfig` 与脚本目录，然后创建 `AgentKernel`（负责装配 WebSocket、Reporter、执行协调器、持久化队列等依赖）。
3. `AgentKernel` 启动 `AgentWebSocketClient`，连接 `agentWs`，并准备一个持久化 Reporter 队列（按 `tenantId/userId/pcId/deviceId` 分区）。
4. 连接成功后发送 `REGISTER`：
   - 基本信息：`tenantId`、`userId`、`pcId`、`deviceId`。
   - `agentVersion`、`buildNumber`。
   - `scriptCatalog`：内置脚本列表、版本、参数 schema。
   - 运行环境：Android 版本、设备型号、可选能力（OpenCV、IME）。
5. 等待 Server `REGISTER_ACK`，若校验失败退出；成功后立刻重放队列中所有未确认消息。

## 2. 待机状态

- 状态机进入 `IDLE`。
- 定时发送 `HEARTBEAT`（默认 5 秒），包含 CPU/内存、最近任务状态。
- 可接收 Server 下发的 `PING` 并返回 `PONG`。

## 3. 执行任务

### 接收指令
1. 收到 `EXECUTE` 命令后，验证：
   - `scriptId` 是否存在于内置脚本目录；
   - `scriptVersion` 是否匹配；
   - 当前状态是否 `IDLE`。
   - 若 payload 中带有 `assets`，验证下载地址与大小限制，并准备临时目录。
2. 若验证通过，交由 `ExecutionCoordinator` 进入 `RUNNING`（ACK/ERROR 回传将在后续扩展）。
3. 若失败，当前实现会记录日志并返回标准执行失败结果（`SCRIPT_NOT_FOUND` 等），同时通过 `executions.ack` 回执失败原因。

### 运行流程
1. 构造 `ExecutionContext`（deviceId、parameters、timeout 等）。
2. 调用 `ScriptRunner` 执行脚本逻辑：
   - 脚本可同步或异步执行，Runner 负责捕获异常。
   - 若存在附件，先下载到临时目录并在 `ExecutionContext` 中注入访问路径。
3. 期间调用 `Reporter` 发送进度事件（步骤开始/结束、日志信息、截图元数据）。
4. 如果超时或收到取消命令，Runner 中断脚本执行，发送失败结果。

### 完成
1. 脚本返回 `ExecutionResult`（状态、摘要、附件列表）。
2. Reporter 通过 WebSocket 发送 `executions.result` 消息（成功/失败）。
3. 状态机回到 `IDLE`，拉取队列中下一个任务。
4. Reporter 等待 Server 发送 `ackType:"RESULT"` 的 ACK，再将结果记录从队列中删除。
5. 清理临时附件目录。

## 4. 心跳与健康检查

- 心跳 payload：
  ```json
  {
    "event": "HEARTBEAT",
    "deviceId": "...",
    "pcId": "...",
    "timestamp": "...",
    "metrics": { "cpu": 0.18, "mem": 256 },
    "lastExecution": {
      "executionId": "...",
      "status": "SUCCESS",
      "finishedAt": "..."
    }
  }
  ```
- 若 WS 断线，`WsClient` 尝试指数退避重连。
- 重连成功后执行以下握手：
  1. 重新发送 `REGISTER`，并在 payload 中补充 `recentExecutions` 数组（最多 5 条），每条包含 `executionId`、`status`、`finishedAt`、`resultSummary`。
  2. 将最近一次心跳指标（CPU、内存、网络质量）一并带入 `REGISTER.metricsSnapshot`，避免等待下一次心跳。
  3. Server 会以 `type: "REPLY", topic: "agents.status"`、`payload.event: "REGISTER_ACK"` 确认；收到 `ACK` 后立即补发因断线积压的心跳（含最新 `lastExecution` 信息），确保上游状态一致。

## 5. 退出

- 接收到 Server `SHUTDOWN` 指令或本地终止信号：
  - 发送 `DEREGISTER`；
  - 关闭 WS；
  - 调用 `finishInstrumentation()`。
- 异常退出时，下一次上线交由 PC 重新启动。

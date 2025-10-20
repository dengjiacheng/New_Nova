# 运行生命周期

## 1. 启动

1. Runner 收到 `onStart` 回调，读取 `InstrumentationArguments`。
2. 初始化配置（依赖注入容器、日志、脚本目录）。
3. 启动 `WsClient`，连接 `agentWs`。
4. 连接成功后发送 `REGISTER`：
   - 基本信息：`tenantId`、`userId`、`pcId`、`deviceId`。
   - `agentVersion`、`buildNumber`。
   - `scriptCatalog`：内置脚本列表、版本、参数 schema。
   - 运行环境：Android 版本、设备型号、可选能力（OpenCV、IME）。
5. 等待 Server `ACK`，若校验失败退出。

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
2. 若验证通过，回复 `ACK_EXECUTE` 并转入 `RUNNING`。
3. 若失败，发送 `ERROR`（`SCRIPT_NOT_FOUND` 等）。

### 运行流程
1. 构造 `ExecutionContext`（deviceId、parameters、timeout 等）。
2. 调用 `ScriptRunner` 执行脚本逻辑：
   - 脚本可同步或异步执行，Runner 负责捕获异常。
   - 若存在附件，先下载到临时目录并在 `ExecutionContext` 中注入访问路径。
3. 期间调用 `Reporter` 发送进度事件（步骤开始/结束、日志信息、截图元数据）。
4. 如果超时或收到取消命令，Runner 中断脚本执行，发送失败结果。

### 完成
1. 脚本返回 `ExecutionResult`（状态、摘要、附件列表）。
2. Runner 发送 `COMPLETE`/`FAILED` 消息。
3. 状态机回到 `IDLE`，拉取队列中下一个任务。
4. 清理临时附件目录。

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
- 重连成功后，重新发送 `REGISTER`，并附带 `recentExecutions` 便于 Server 对齐状态。

## 5. 退出

- 接收到 Server `SHUTDOWN` 指令或本地终止信号：
  - 发送 `DEREGISTER`；
  - 关闭 WS；
  - 调用 `finishInstrumentation()`。
- 异常退出时，下一次上线交由 PC 重新启动。

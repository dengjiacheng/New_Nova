# 指令处理与状态机

## 状态机定义

| 状态 | 描述 | 可接受指令 |
| --- | --- | --- |
| `INIT` | 启动中、等待注册成功 | - |
| `IDLE` | 待命，准备接收执行请求 | `EXECUTE`, `PING`, `SHUTDOWN` |
| `RUNNING` | 执行脚本中 | `CANCEL`, `PING`, `SHUTDOWN` |
| `STOPPING` | 正在终止执行 | - |
| `ERROR` | 发生不可恢复错误 | `RESET`（可选） |

状态转换：
- `INIT` → `IDLE`: 注册成功。
- `IDLE` → `RUNNING`: 接到 `EXECUTE` 并确认。
- `RUNNING` → `IDLE`: 正常完成或失败。
- `RUNNING` → `STOPPING`: 收到 `CANCEL` 或超时。
- `STOPPING` → `IDLE`: 清理完成。
- 任意状态 → `ERROR`: 严重异常（如脚本目录损坏）。

## 指令列表与路由

`AgentMessageRouter` 会对 `type: "COMMAND", topic: "executions.command"` 的消息进行预解析：

| 指令 | 来源 | 作用 | 当前状态 |
| --- | --- | --- | --- |
| `EXECUTE` | Server | 启动脚本执行 | 已接入 `ExecutionCoordinator` |
| `CANCEL` | Server | 强制取消当前执行 | 已接入（取消信号透传） |
| `SHUTDOWN` | Server | 停止 Agent 并下线 | TODO |
| `PING` | Server | 心跳测试，Agent 回复 `PONG` | TODO |
| `RESET` | Server | 在 `ERROR` 状态下请求自恢复（可选） | TODO |
| `ACK` (`executions.ack`) | 双向 | 命令确认、上报确认 | 新增 |

## 处理逻辑

### EXECUTE
1. 验证当前状态 `IDLE`。
2. 校验脚本存在与版本一致。
3. 构建 `ExecutionTask`：
   ```kotlin
   data class ExecutionTask(
       val executionId: String,
       val scriptId: String,
       val scriptVersion: String,
       val parameters: JsonObject,
       val timeoutMs: Long,
       val options: Map<String, Any>
   )
   ```
4. 推入执行队列，切换状态 `RUNNING`。
5. 若命令包含 `assets`，在进入脚本前同步/异步下载所需资源，失败时返回 `SCRIPT_NOT_FOUND`/`ASSET_DOWNLOAD_FAILED` 等执行结果。
6. 返回 `executions.ack`（`ackType:"COMMAND"`）给 Server，表明命令已进入执行队列；若拒绝执行，`status:"REJECTED"` 并携带错误码。

### CANCEL
1. 若状态非 `RUNNING`，返回 `NO_TASK_RUNNING` 并通过 ACK 回执 `status:"REJECTED"`。
2. 向当前脚本发送取消信号（可使用 `CancellationToken`）。
3. 进入 `STOPPING`，等待脚本释放资源后发送 `FAILED`（错误码 `CANCELLED_BY_SERVER`）。

### SHUTDOWN
1. 若正在执行，先执行 `CANCEL` 流程。
2. 发送 `ACK_SHUTDOWN`，切换状态 `STOPPING`。
3. 完成清理后发送 `DEREGISTER`，调用 `finishInstrumentation()`。

### PING
1. 立即回复 `PONG` 或 `executions.ack`，携带当前状态与最近心跳时间。

### RESET（可选）
1. 在 `ERROR` 状态下清理脚本环境、恢复到 `IDLE`。

## 错误处理

- 指令解析失败 → 回复 `ERROR`，错误码 `INVALID_COMMAND`。
- JSON 解析异常 → 回复 `ERROR`，错误码 `INVALID_PAYLOAD`。
- 未知脚本 → `ERROR`，错误码 `SCRIPT_NOT_FOUND`。
- 版本不匹配 → `ERROR`，错误码 `SCRIPT_VERSION_MISMATCH`。
- 对于所有错误，仍需发送 `executions.ack`，`status:"REJECTED"` 并在 `payload.error` 中填入错误码。

所有错误都应记录日志，并在心跳中附带 `lastError` 字段，帮助 Server 告警。

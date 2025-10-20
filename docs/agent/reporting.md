# 执行报告与日志回传

Agent 在脚本执行过程中需要持续向 Server 汇报状态、日志与附件。此文档定义 Reporter 设计。

## Reporter 接口

```kotlin
interface Reporter {
    suspend fun sendProgress(event: ProgressEvent)
    suspend fun sendLog(log: LogEvent)
    suspend fun sendAttachment(attachment: AttachmentEvent)
    suspend fun sendResult(result: ExecutionResultEvent)
}
```

- `ProgressEvent`：步骤信息（开始/结束、耗时）。
- `LogEvent`：文本日志，支持级别 INFO/WARN/ERROR。
- `AttachmentEvent`：截图或文件，包含 `type`、`downloadUrl`（若本地存储后上传）或 Base64（小文件）。
- `ExecutionResultEvent`：成功/失败结果。

## 事件结构

### ProgressEvent
```json
{
  "executionId": "EXEC-...",
  "stepIndex": 2,
  "stepName": "输入用户名",
  "status": "RUNNING",        // RUNNING | SUCCESS | FAILED
  "timestamp": "2024-06-01T12:01:02Z"
}
```

### LogEvent
```json
{
  "executionId": "EXEC-...",
  "level": "INFO",
  "message": "正在等待验证码",
  "timestamp": "2024-06-01T12:01:05Z"
}
```

### AttachmentEvent
```json
{
  "executionId": "EXEC-...",
  "attachmentId": "ATT-001",
  "type": "SCREENSHOT",
  "fileName": "step2.png",
  "contentType": "image/png",
  "data": "<base64>",           // 小文件直接附带；大文件可上传后返回 URL
  "timestamp": "2024-06-01T12:01:10Z"
}
```

### ExecutionResultEvent
```json
{
  "executionId": "EXEC-...",
  "status": "SUCCESS",
  "summary": "登录成功",
  "durationMs": 58234,
  "error": null,
  "outputs": {
    "username": "demo"
  }
}
```

失败时：
```json
{
  "status": "FAILED",
  "summary": "登录失败",
  "error": {
    "code": "LOGIN_TIMEOUT",
    "message": "等待验证码超时",
    "details": { "timeout": 60 }
  }
}
```

## 回传策略

- Reporter 根据事件类型将数据封装为 WS 消息：
  - `ProgressEvent` → `executions.progress`
  - `LogEvent` → `executions.progress`（`eventType: LOG`）
  - `AttachmentEvent` → `executions.progress`（`eventType: ATTACHMENT`）
  - `ExecutionResultEvent` → `executions.result`
- 若网络暂时不可用，Reporter 将事件缓存在内存队列，待重连后重放。
- 为避免内存溢出，可限制队列大小；超过限制时丢弃较旧日志并记录告警。

## 日志级别与脱敏

- 默认记录 INFO 级别；可通过配置提升至 DEBUG。
- 含密码等敏感信息的日志需脱敏或避免输出。

## 本地持久化（可选）

- 在执行过程中将日志写入本地文件，执行完后上传对象存储并返回 URL。
- 若本地存储不可用，可仅依靠实时回传。

## Server 端处理

- Server 将事件转发给 PC 客户端，并可选择持久化（详见 `server/background_tasks.md`）。
- 需要在执行记录中冗余 `summary`、`errorCode` 等，以便后续审计。

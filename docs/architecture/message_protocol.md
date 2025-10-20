# 消息与数据契约（总览）

## REST API 响应规范

- 统一返回结构：

```json
{
  "code": "OK",
  "message": "optional message",
  "data": { "..." : "..." },
  "traceId": "uuid"
}
```

- `code` 采用语义化常量：`OK`、`AUTH_FAILED`、`INSUFFICIENT_BALANCE`、`DEVICE_OFFLINE`、`FEATURE_NOT_IMPLEMENTED` 等。
- `traceId` 由 Server 注入，用于链路追踪与日志关联。
- 错误时 `data` 可省略或包含错误上下文（避免敏感信息）。

## WebSocket 消息 Envelopes

所有 WS 消息遵循以下结构，由 `type` 区分方向：

```json
{
  "version": "1.0",
  "type": "EVENT|COMMAND|REPLY|ERROR",
  "topic": "agents.status|executions.progress|...",
  "correlationId": "uuid",
  "timestamp": "2024-06-01T12:00:00Z",
  "payload": { "...": "..." }
}
```

- `correlationId`：服务端命令与 Agent 响应的关联键；事件型消息可使用新的 UUID。
- `topic`：用于客户端订阅过滤，具体取值在下文定义。
- `timestamp`：ISO-8601 UTC 时间。

## 主要 Topic 列表

| Topic | 方向 | 说明 |
| --- | --- | --- |
| `agents.status` | Server → PC | 设备上线/下线、心跳告警 |
| `executions.progress` | Server → PC | 脚本执行进度、日志、阶段结果 |
| `executions.result` | Server → PC | 执行完成或失败通知 |
| `executions.command` | Server → Agent | 发送执行指令 |
| `executions.reply` | Agent → Server | 执行响应，包括开始、进度、完成 |
| `system.notice` | Server → PC | 余额不足、脚本授权到期等 |

## 执行指令示例

### Server → Agent `EXECUTE`

```json
{
  "version": "1.0",
  "type": "COMMAND",
  "topic": "executions.command",
  "correlationId": "EXEC-20240601-0001",
  "payload": {
    "command": "EXECUTE",
    "executionId": "EXEC-20240601-0001",
    "script": {
      "id": "SCRIPT_LOGIN",
      "version": "1.2.0"
    },
    "pcId": "PC-123",
    "deviceId": "emulator-5554",
    "tenantId": "TEN-001",
    "userId": "USR-789",
    "parameters": {
      "username": "demo",
      "password": "123456",
      "timeout": 30
    },
    "assets": [
      {
        "assetId": "AST-20240601-0009",
        "field": "templateImage",
        "fileName": "login_template.png",
        "contentType": "image/png",
        "size": 48213,
        "downloadUrl": "https://cdn.example.com/temp/AST-20240601-0009?sig=..."
      }
    ],
    "options": {
      "retryOnFailure": false
    }
  }
}
```

### Agent → Server 进度回报

```json
{
  "version": "1.0",
  "type": "EVENT",
  "topic": "executions.progress",
  "correlationId": "EXEC-20240601-0001",
  "payload": {
    "executionId": "EXEC-20240601-0001",
    "stage": "STEP",
    "stepIndex": 3,
    "stepName": "输入验证码",
    "status": "RUNNING",
    "timestamp": "2024-06-01T12:01:05Z",
    "attachments": []
  }
}
```

### Agent → Server 完成响应

```json
{
  "version": "1.0",
  "type": "REPLY",
  "topic": "executions.result",
  "correlationId": "EXEC-20240601-0001",
  "payload": {
    "executionId": "EXEC-20240601-0001",
    "status": "SUCCESS",
    "durationMs": 58234,
    "output": {
      "summary": "登录成功",
      "artifacts": []
    },
    "error": null
  }
}
```

失败时 `status` 改为 `FAILED`，`error` 包含 `code` 与 `message`。

## Agent 注册与心跳

- 注册请求（Agent → Server）：

```json
{
  "version": "1.0",
  "type": "EVENT",
  "topic": "agents.status",
  "correlationId": "REG-<uuid>",
  "payload": {
    "event": "REGISTER",
    "tenantId": "TEN-001",
    "userId": "USR-789",
    "pcId": "PC-123",
    "deviceId": "emulator-5554",
    "agentVersion": "2.0.0",
    "scriptCatalog": [
      { "id": "SCRIPT_LOGIN", "version": "1.2.0" },
      { "id": "SCRIPT_CHECKOUT", "version": "1.0.5" }
    ],
    "capabilities": {
      "opencv": true,
      "ime": false
    }
  }
}
```

- 心跳消息可使用 `event: "HEARTBEAT"`，包含最近任务、资源占用等摘要。

## 状态枚举

| 枚举 | 描述 |
| --- | --- |
| 执行状态：`QUEUED`, `RUNNING`, `SUCCESS`, `FAILED`, `CANCELLED_DEVICE_OFFLINE`, `CANCELLED_USER` |
| Agent 事件：`REGISTER`, `HEARTBEAT`, `DEREGISTER` |
| 错误码：`SCRIPT_VERSION_MISMATCH`, `AGENT_OFFLINE`, `UNAUTHORIZED`, `INSUFFICIENT_BALANCE`, `EXECUTION_TIMEOUT`, `INTERNAL_ERROR` |

枚举表需在服务端与客户端共用，建议维护在共享配置/SDK 中。

## 二进制资源传递

- 当脚本参数需要图片等二进制内容时，PC 端在创建执行任务前调用资源上传接口获取 `assetId` 与临时下载地址（详见 `server/rest_api.md`）。
- 执行请求在 `assets` 字段中引述资源，并指明它与哪个参数字段对应；Server 派发命令时携带签名 URL（或对小文件进行 Base64 内联）。
- Agent 接收命令后按 `downloadUrl` 拉取资源，存入本地临时目录，执行完成后清理；下载失败需返回错误 `ASSET_DOWNLOAD_FAILED`。
- Server 为临时资源设定过期时间，通过后台任务定期清理。

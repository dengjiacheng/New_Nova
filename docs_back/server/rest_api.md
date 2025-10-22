# REST API 设计

所有接口前缀 `/api/`，返回统一 JSON 结构（见 `architecture/message_protocol.md`）。需要 JWT 鉴权的接口通过 `Authorization: Bearer <token>` 传递。

## 1. 认证

### `POST /api/auth/login`
- 请求：
  ```json
  { "username": "demo", "password": "******", "pcId": "PC-123" }
  ```
- 响应：
  ```json
  {
    "code": "OK",
    "data": {
      "token": "<jwt>",
      "refreshToken": "<jwt>",
      "tenant": { "id": "TEN-001", "name": "示例企业" },
      "user": { "id": "USR-789", "roles": ["ADMIN"] },
      "balance": 520.34
    }
  }
  ```
- 说明：登录时附带 `pcId`，便于 Server 记录活跃终端。

### `POST /api/auth/refresh`
- 请求：`{ "refreshToken": "<jwt>" }`
- 响应：与登录相同（不返回用户信息可选）。

### `POST /api/auth/logout`
- 请求：空
- 响应：`code: OK`，Server 记录注销事件。

## 2. 脚本目录与购买

### `GET /api/scripts`
- 查询可购买/已购脚本列表，支持分页与分类过滤。
- 响应字段：
  ```json
  {
    "scripts": [
      {
        "id": "SCRIPT_LOGIN",
        "name": "登录脚本",
        "version": "1.2.0",
        "description": "...",
        "purchasePrice": 199.0,
        "executionPrice": 2.0,
        "capabilities": { "requiresOpenCv": false },
        "purchased": true
      }
    ]
  }
  ```

### `POST /api/scripts/{scriptId}/purchase`
- 请求：`{ "pcId": "PC-123" }`（记录来源 PC，可选）
- 逻辑：校验是否已购买；扣款成功后返回成功状态。
- 响应：`{ "code": "OK", "data": { "balance": 320.0 } }`

### `GET /api/scripts/purchased`
- 返回当前用户已购脚本列表及版本信息。

## 3. 设备状态

### `GET /api/devices`
- 查询当前账号下在线设备列表（仅内存态）。
- 响应：
  ```json
  {
    "devices": [
      {
        "pcId": "PC-123",
        "deviceId": "emulator-5554",
        "status": "ONLINE",
        "agentVersion": "2.0.0",
        "lastHeartbeat": "2024-06-01T12:00:30Z",
        "currentExecution": null
      }
    ]
  }
  ```

### `POST /api/devices/{deviceId}/stop`
- 功能：通知 Server 主动断开 Agent（Server 发送 `SHUTDOWN` 指令）。
- 参数：`{ "pcId": "PC-123" }`
- 响应：`code: OK`

## 4. 执行任务

### `POST /api/executions`
- 功能：批量创建执行任务。
- 请求：
  ```json
  {
    "pcId": "PC-123",
    "requests": [
      {
        "deviceId": "emulator-5554",
        "scriptId": "SCRIPT_LOGIN",
        "scriptVersion": "1.2.0",
        "parameters": { "username": "demo", "password": "123456" },
        "templateMeta": { "name": "默认登录", "checksum": "sha256..." },
        "assets": [
          {
            "assetId": "AST-20240601-0009",
            "field": "templateImage"
          }
        ],
        "options": { "timeout": 120000 }
      }
    ]
  }
  ```
- 响应：
  ```json
  {
    "executions": [
      {
        "executionId": "EXEC-20240601-0001",
        "deviceId": "emulator-5554",
        "status": "QUEUED",
        "charged": 2.0,
        "balance": 318.0
      }
    ]
  }
  ```
- 异常：
  - `INSUFFICIENT_BALANCE`
  - `SCRIPT_NOT_PURCHASED`
  - `DEVICE_OFFLINE`
  - `SCRIPT_VERSION_MISMATCH`

### `GET /api/executions`
- 查询执行历史，支持过滤条件：
  - `scriptId`、`status`、`deviceId`、`pcId`、时间范围。
- 响应记录字段：
  ```json
  {
    "records": [
      {
        "executionId": "EXEC-20240601-0001",
        "scriptId": "SCRIPT_LOGIN",
        "deviceId": "emulator-5554",
        "pcId": "PC-123",
        "status": "SUCCESS",
        "charged": 2.0,
        "startedAt": "2024-06-01T12:00:30Z",
        "finishedAt": "2024-06-01T12:01:28Z",
        "parameters": { "username": "***" },
        "result": {
          "summary": "登录成功",
          "errorCode": null
        }
      }
    ]
  }
  ```
- `parameters` 中敏感字段可脱敏存储。

### `POST /api/executions/{executionId}/cancel`
- 功能：在任务排队或运行中请求取消。
  - Server 若任务已执行完，返回 `code: EXECUTION_NOT_CANCELLABLE`。

## 5. 计费与充值

### `GET /api/billing/balance`
- 返回当前余额、冻结金额等。

### `POST /api/billing/recharge`
- 超级管理员或支付回调更新余额。
- 请求：`{ "amount": 500.0, "reference": "ORDER-001" }`

### `GET /api/billing/transactions`
- 查询消费与充值流水。
- 记录字段：`transactionId`、`type (PURCHASE|EXECUTION|RECHARGE)`、`amount`、`scriptId`、`executionId`、`pcId`、时间戳。

## 6. 执行资源上传

用于上传脚本执行所需的临时附件（图片、配置包等）。资源默认在 24 小时后自动清理。

### `POST /api/executions/assets`
- Content-Type: `multipart/form-data`
- 字段：
  - `file`：二进制文件内容
  - `field`：对应模板字段名（可选）
  - `scriptId`：脚本标识（可选，用于验证）
- 响应：
  ```json
  {
    "code": "OK",
    "data": {
      "assetId": "AST-20240601-0009",
      "fileName": "login_template.png",
      "contentType": "image/png",
      "size": 48213,
      "downloadUrl": "https://cdn.example.com/temp/AST-20240601-0009?sig=...",
      "expiresAt": "2024-06-02T12:00:00Z"
    }
  }
  ```
- 使用方法：NovaDesk 上传文件后，在 `POST /api/executions` 请求中引用 `assetId`。Server 派发命令时包含 `downloadUrl`（签名地址），Agent 据此下载。

### `DELETE /api/executions/assets/{assetId}`
- 可选接口，允许客户端主动删除未使用的资源。
- 响应：`code: OK`

## 7. Agent 包管理

### `POST /api/admin/agent-packages`
- 权限：`ADMIN`、`SUPER_ADMIN`（建议仅 `SUPER_ADMIN` 可设置激活版本）。
- Content-Type: `multipart/form-data`
- 字段：
  - `file`：APK 二进制内容，必填。
  - `versionName`：字符串，必填。
  - `versionCode`：整数，必填，需大于 0。
  - `releaseNotes`：可选文本，支持 Markdown（后端会自动去除首尾空白）。
  - `checksum`：可选，若客户端已计算 SHA256 可一并提交用于校验；格式示例 `sha256:xxxx`。
- 响应：
  ```json
  {
    "code": "OK",
    "data": {
      "packageId": "AGP-20241101-0001",
      "versionName": "2.1.0",
      "versionCode": 2100,
      "fileSize": 58234912,
      "checksum": "sha256:...",
      "uploadedBy": { "id": "USR-789", "name": "Alice" },
      "uploadedAt": "2024-11-01T08:00:00Z",
      "status": "DRAFT"
    }
  }
  ```
- 说明：
  - Server 会保存文件到配置项 `NOVASERVER_AGENT_PACKAGE_STORAGE_DIR` 指定目录，并将元数据写入数据库；若与请求 `checksum` 不符返回 `CHECKSUM_MISMATCH`。
  - 默认状态为 `DRAFT`，需调用激活接口后才会被 PC 端发现。

### `GET /api/admin/agent-packages`
- 功能：列出已有 APK 元数据，默认按 `uploadedAt DESC` 排序。
- 响应：
  ```json
  {
    "code": "OK",
    "data": {
      "items": [
        {
          "packageId": "AGP-20241101-0001",
          "versionName": "2.1.0",
          "versionCode": 2100,
          "fileSize": 58234912,
          "checksum": "sha256:...",
          "uploadedBy": { "id": "USR-789", "name": "Alice" },
          "uploadedAt": "2024-11-01T08:00:00Z",
          "status": "ACTIVE",
          "downloadUrl": "/api/admin/agent-packages/AGP-20241101-0001/download"
        }
      ]
    }
  }
  ```
- 说明：`downloadUrl` 为 Server 内置下载接口（需要管理员身份），可供 Admin Tools 页面直接拉取校验。

### `POST /api/admin/agent-packages/{packageId}/activate`
- 功能：将指定版本标记为当前激活版本，供 NovaDesk/部署脚本使用。
- 请求：`{ "notes": "Roll out to all PCs" }`（可选，记录变更说明）。
- 响应：`{ "code": "OK" }`
- 副作用：将指定包状态更新为 `ACTIVE`，其余已激活版本会自动切换为 `ARCHIVED`。后续可拓展广播通知机制。

### `DELETE /api/admin/agent-packages/{packageId}`
- 功能：删除指定版本（含本地存储文件）。
- 响应：`{ "code": "OK" }`
- 说明：如果删除的是当前激活版本，将导致 `GET /api/agent-packages/latest` 返回 404；文件不存在也会返回 200（忽略）。

### `GET /api/agent-packages/latest`
- 功能：公开获取当前激活的 Agent 包信息（用于 NovaDesk 自动检测更新）。
- 响应：
  ```json
  {
    "code": "OK",
    "data": {
      "packageId": "AGP-20241101-0001",
      "versionName": "2.1.0",
      "versionCode": 2100,
      "downloadUrl": "/api/admin/agent-packages/AGP-20241101-0001/download",
      "checksum": "sha256:...",
      "releaseNotes": "..."
    }
  }
  ```
- 说明：若当前没有激活版本，则返回 `404 AGENT_PACKAGE_NOT_FOUND`；接口无需登录，可直接供 NovaDesk 检测更新使用。

## 8. 超级管理员接口

仅超级管理员角色可访问：
- `POST /api/admin/tenants`：创建租户，设置初始余额。
- `GET /api/admin/tenants`：查看租户与余额。
- `POST /api/admin/users`：创建租户管理员。
- `GET /api/admin/audit`：查询审计日志。

## 安全建议

- 所有写操作需要 CSRF 防护（若未来提供 Web Console）。
- 密码登录建议支持 MFA；后续可扩展 OAuth/SAML。
- 审计日志操作添加 `X-Request-Id` 头部，便于追踪。

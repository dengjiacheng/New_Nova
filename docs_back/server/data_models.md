# 数据模型设计（PostgreSQL）

设备在线信息不持久化，本节仅描述需要落库的实体。

## 1. 租户与用户

| 表 | 说明 |
| --- | --- |
| `tenants` | 租户基础信息、状态（启用/禁用）、余额等 |
| `tenant_balances` | 余额表（当前余额、冻结金额、上次更新时间） |
| `users` | 用户账号（隶属租户）、角色（`SUPER_ADMIN`、`ADMIN`、`USER`）、状态 |
| `user_sessions` | 可选，用于记录活跃 JWT 或登录日志 |

### `tenants`
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | UUID | 主键 |
| `name` | VARCHAR | 租户名称 |
| `status` | ENUM | `ACTIVE` / `SUSPENDED` |
| `created_at` | TIMESTAMP | 创建时间 |
| `updated_at` | TIMESTAMP | 更新时间 |

### `tenant_balances`
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `tenant_id` | UUID | FK → tenants.id |
| `balance` | NUMERIC(12,2) | 当前余额 |
| `frozen` | NUMERIC(12,2) | 冻结金额 |
| `updated_at` | TIMESTAMP | 更新时间 |

### `users`
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | UUID | 主键 |
| `tenant_id` | UUID | FK → tenants.id |
| `username` | VARCHAR | 唯一 |
| `password_hash` | VARCHAR | PBKDF2/BCrypt |
| `role` | ENUM | `SUPER_ADMIN` / `ADMIN` / `USER` |
| `status` | ENUM | `ACTIVE` / `DISABLED` |
| `created_at`, `updated_at` | TIMESTAMP | - |

## 2. 脚本与授权

| 表 | 说明 |
| --- | --- |
| `scripts` | 脚本元数据（ID、名称、版本、收费策略、依赖能力） |
| `script_versions` | 可选；若需要保留历史版本信息 |
| `script_purchases` | 用户购买记录，一次性授权 |

### `scripts`
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | VARCHAR | 主键（与 Agent 内置脚本 ID 对应） |
| `name` | VARCHAR | 名称 |
| `description` | TEXT | 描述 |
| `latest_version` | VARCHAR | 最新版本号 |
| `purchase_price` | NUMERIC | 购买费用 |
| `execution_price` | NUMERIC | 单次执行费用 |
| `capabilities` | JSONB | 依赖能力（`requiresOpencv` 等） |
| `created_at`, `updated_at` | TIMESTAMP | - |

### `script_purchases`
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | UUID | 主键 |
| `tenant_id` | UUID | FK → tenants.id |
| `user_id` | UUID | FK → users.id（可选） |
| `script_id` | VARCHAR | FK → scripts.id |
| `script_version` | VARCHAR | 购买时版本 |
| `price` | NUMERIC | 扣费金额 |
| `purchased_at` | TIMESTAMP | 购买时间 |

## 3. 执行任务

| 表 | 说明 |
| --- | --- |
| `executions` | 每次执行任务主表 |
| `execution_events` | 进度事件日志（可选，为避免膨胀可写入对象存储） |

### `executions`
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | UUID | `executionId` |
| `tenant_id`, `user_id` | UUID | - |
| `pc_id` | VARCHAR | 发起任务的 PC |
| `device_id` | VARCHAR | 执行设备标识（冗余） |
| `script_id` | VARCHAR | - |
| `script_version` | VARCHAR | - |
| `parameters` | JSONB | 参数快照（执行时的值，敏感字段可脱敏） |
| `status` | ENUM | `QUEUED` / `RUNNING` / `SUCCESS` / `FAILED` / `CANCELLED_*` |
| `charged_amount` | NUMERIC | 本次扣费金额 |
| `result_summary` | JSONB | 结果摘要（成功/失败信息、错误码） |
| `started_at`, `finished_at` | TIMESTAMP | - |
| `created_at`, `updated_at` | TIMESTAMP | - |

### `execution_events`（可选）
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | BIGSERIAL | 主键 |
| `execution_id` | UUID | FK → executions.id |
| `event_type` | ENUM | `STEP`, `LOG`, `ATTACHMENT` |
| `event_payload` | JSONB | 具体内容 |
| `timestamp` | TIMESTAMP | - |

若不落库，可改为写入对象存储并记录索引。

## 4. 计费与交易

| 表 | 说明 |
| --- | --- |
| `transactions` | 所有扣费/充值流水 |
| `invoices` | 可选，若需要周期账单 |
| `execution_assets` | 临时执行附件元数据 |

### `transactions`
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | UUID | 主键 |
| `tenant_id` | UUID | - |
| `user_id` | UUID | 操作者 |
| `pc_id` | VARCHAR | 来源 PC |
| `type` | ENUM | `PURCHASE` / `EXECUTION` / `RECHARGE` / `ADJUSTMENT` |
| `amount` | NUMERIC | 正数为充值，负数为扣费 |
| `script_id` | VARCHAR | 可空 |
| `execution_id` | UUID | 可空 |
| `reference` | VARCHAR | 外部订单或备注 |
| `created_at` | TIMESTAMP | - |

### `execution_assets`
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | UUID | 主键，对应 `assetId` |
| `tenant_id` | UUID | 上传者所属租户 |
| `user_id` | UUID | 上传者 |
| `pc_id` | VARCHAR | 来源 PC |
| `script_id` | VARCHAR | 可选，限制用途 |
| `field` | VARCHAR | 对应模板字段 |
| `file_name` | VARCHAR | 原始文件名 |
| `content_type` | VARCHAR | MIME 类型 |
| `size` | BIGINT | 字节数 |
| `storage_key` | VARCHAR | 对象存储路径或引用 |
| `download_url` | VARCHAR | 签名地址（可选缓存） |
| `expires_at` | TIMESTAMP | 资源过期时间 |
| `created_at` | TIMESTAMP | 上传时间 |

清理任务根据 `expires_at` 删除记录并触发对象存储删除。

## 5. 审计日志

| 表 | 说明 |
| --- | --- |
| `audit_logs` | 熱存储审计记录 |

### `audit_logs`
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | UUID | 主键 |
| `tenant_id` | UUID | - |
| `user_id` | UUID | 操作者 |
| `pc_id` | VARCHAR | 来源 PC |
| `action` | ENUM | `SCRIPT_EXECUTE`, `SCRIPT_PURCHASE`, `LOGIN` 等 |
| `target_id` | VARCHAR | 关联对象（如 `executionId`） |
| `metadata` | JSONB | 详细信息（参数摘要、结果等） |
| `created_at` | TIMESTAMP | 时间 |

定期归档流程会将超过保留期的记录导出至对象存储，并在表中删除或标记。

## 6. Agent 包管理

| 表 | 说明 |
| --- | --- |
| `agent_packages` | Agent APK 元数据与状态 |

### `agent_packages`
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | UUID | 主键，对应 `packageId` |
| `version_name` | VARCHAR | APK `versionName` |
| `version_code` | INTEGER | APK `versionCode` |
| `file_name` | VARCHAR | 原始文件名 |
| `file_size` | BIGINT | 字节数 |
| `checksum` | VARCHAR | `sha256:<hash>` |
| `storage_path` | VARCHAR | 文件存储路径（当前为本地目录，可替换为对象存储 Key） |
| `release_notes` | TEXT | 发布说明（Markdown） |
| `status` | ENUM | `DRAFT` / `ACTIVE` / `ARCHIVED` |
| `uploaded_by` | UUID | FK → users.id |
| `uploaded_at` | TIMESTAMP | 上传时间 |
| `activated_by` | UUID | FK → users.id，可空 |
| `activated_at` | TIMESTAMP | 激活时间，可空 |

> 说明：
> - 上传成功后默认状态为 `DRAFT`，只有 `ACTIVE` 版本会在 `GET /api/agent-packages/latest` 中返回。
> - 当前服务端实现使用数据库持久化元数据，APK 文件落在 `AGENT_PACKAGE_STORAGE_DIR`。后续若接入对象存储，可将 `storage_path` 替换为存储 Key。

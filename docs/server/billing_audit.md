# 计费与审计流程

## 计费模型

- **脚本购买费**：一次性扣费，授权用户/租户长期使用指定脚本。如脚本升级，是否重新收费可按策略配置（默认免费升级）。
- **脚本执行费**：按执行次数收费，每次执行即扣费一次；多设备并行时，按提交的每个设备任务分别扣费。
- **余额管理**：`tenant_balances.balance` 表示可用余额；扣费为负值、充值为正值。
- **扣费时机**：执行任务创建成功即扣费。若任务因设备离线等原因未真正执行，可配置退款策略（默认不退，需人工补偿）。

## 扣费流程

1. PC 提交执行请求。
2. Server 校验脚本是否已购买（查询 `script_purchases`）。
3. 计算执行费用：`execution_price × 请求条数`。
4. 使用事务：
   - 将金额写入 `transactions`（type=`EXECUTION`，amount = -费用）。
   - 更新 `tenant_balances.balance -= 费用`。
   - 创建 `executions` 记录并写入 `charged_amount`。
5. 提交成功后放入设备队列；失败返回错误并回滚。

## 消费流水

- `transactions` 记录所有扣费/充值，字段包含 `pcId`、`scriptId`、`executionId`（如适用）。
- 提供查询接口按时间、类型、脚本检索，支持导出 CSV。
- 可选：每日或每月生成汇总账单表 `billing_summaries`。

## 审计日志

- 记录动作：`LOGIN`、`SCRIPT_PURCHASE`、`SCRIPT_EXECUTE`、`EXECUTION_RESULT`、`BALANCE_ADJUST`。
- `metadata` JSON 包含关键字段：
  - `pcId`、`deviceId`、`scriptId`、`executionId`
  - 参数摘要（敏感字段脱敏）
  - 执行结果与错误码
  - 扣费金额
- 使用 append-only 存储（可写入 PostgreSQL，禁止 UPDATE/DELETE，仅通过归档清理）。

## 归档策略

- 热存储（PostgreSQL）：保留最近 3~6 个月。
- 归档任务：每月初触发，将上月数据导出为 JSON/CSV，压缩上传对象存储（例如 `s3://nova-audit/YYYY/MM/`）。
- 归档完成后，在数据库中删除或标记已归档（保留简短索引以便追溯）。
- 归档文件需带签名或哈希校验，防止被篡改。

## 异常处理

- 扣费失败 → 返回 `INSUFFICIENT_BALANCE`，不创建任务。
- 归档失败 → 记录报警，暂不删除热数据。
- 审计写入失败 → 记录告警并重试，确保关键操作可追溯。

## 接口联动

- REST `/api/billing/transactions`：查询流水。
- REST `/api/admin/audit`：超级管理员审计查询，可按租户过滤。
- 内部任务 `workers.audit_archiver`：定时归档。
- 内部任务 `workers.balance_notifier`：余额阈值预警（推送 `system.notice`）。

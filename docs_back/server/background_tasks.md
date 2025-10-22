# 后台任务与调度

NovaServer 需要一组后台任务保证设备状态、执行队列与归档流程的可靠性。这些任务可以通过 FastAPI 的 `BackgroundTasks`、`asyncio` 循环或外部任务队列（如 Celery）实现，本文以内置异步调度为例。当前代码中 `workers.WorkerManager` 仅启动了执行派发占位循环（遍历频率可配置），其余任务需按本节规划迭代补齐。

## 任务列表

| 任务 | 周期 | 作用 |
| --- | --- | --- |
| `workers.device_heartbeat_watcher` | 5s | 检查 Agent 心跳，标记离线设备，清理队列 |
| `workers.execution_dispatcher` | 持续 | 从设备队列取任务发送 `EXECUTE` 命令，处理 ACK 与重试 |
| `workers.execution_timeout_checker` | 30s | 检测运行中任务是否超时，必要时取消并通知 |
| `workers.audit_logger` | 实时 | 将审计事件写入数据库/队列，确保异步与高可用 |
| `workers.audit_archiver` | 每日/每月 | 导出过期审计与执行记录到冷存储，删除热数据 |
| `workers.balance_notifier` | 1h | 检查余额阈值，推送不足提醒 |
| `workers.billing_reporter` | 每日 | 生成每日消费汇总（可选） |
| `workers.asset_cleaner` | 1h | 清理过期执行资源附件（对象存储文件及元数据） |

## 设备心跳监控

- 每个在线设备持有 `lastHeartbeat` 时间戳。
- `heartbeatTimeout`（例如 15s）内未收到更新则判定离线：
  - 更新内存状态 → `OFFLINE`;
  - 清空该设备队列未开始的任务（状态改 `CANCELLED_DEVICE_OFFLINE`）；
  - 若任务运行中，记录失败并通知 PC。

## 执行调度

- 队列结构：默认使用内存队列 `ExecutionDispatcher`（由服务容器托管）。若需要持久化，可替换为 Redis/消息队列实现，但需保留“单设备串行”的约束。
- `execution_dispatcher` 逐个设备遍历：
  1. 若设备空闲且有排队任务 → 发送 `EXECUTE` 命令。
  2. 等待 Agent 发送 `ACK_EXECUTE`，否则重试/失败。
  3. 将任务状态更新为 `RUNNING`，记录开始时间。
- 支持最大并发：虽然单设备串行，但多设备可同时执行。

## 执行超时

- 每个任务可配置最大耗时（默认 10 分钟，可在脚本配置中定义）。
- 超时则发送 `CANCEL` 命令（若 Agent 支持），并将任务标记为失败，错误码 `EXECUTION_TIMEOUT`。

## 审计写入

- 通过内部事件总线（如 `asyncio.Queue`）接收审计事件。
- 支持批量写入 DB，失败时重试并记录告警。
- 与归档任务配合，保持热存储规模可控。

## 临时资源清理

- 临时资源包括执行附件上传后的文件、签名 URL 记录等。
- `asset_cleaner` 定期扫描数据库/Redis 中的资源元数据，删除已过期的对象存储文件并移除索引。
- 清理失败需要记录警告并重试，避免大量无用文件占用空间。

## 配置与监控

- 所有任务参数应可通过配置文件/环境变量调整。
- 建议集成 Prometheus 指标：队列长度、任务成功率、心跳延迟、归档执行时间等。
- 关键异常需推送告警（邮件、Slack、短信等）。

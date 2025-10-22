# NovaServer 架构重构方案（2025-10-21）

> 本方案用于指导 NovaServer 执行域的重构，消除临时实现导致的耦合膨胀问题，并为三端联调提供可扩展的运行时架构。所有代码变更需先对齐本计划，再同步更新相关文档与测试。

## 重构目标

- **依赖注入统一化**：移除模块级 `get_*` 单例方法，采用应用级服务容器集中管理仓储、队列、账本等依赖，通过 FastAPI `Depends` 传递，确保测试与多实例部署一致。
- **执行域分层**：拆分当前 `ExecutionService` 的“一体化”实现，按用例、校验、计费、队列派发、事件推送划分职责，暴露明确的领域接口，便于替换实现（如切换至数据库/Redis）。
- **协议适配收敛**：WebSocket、后台任务仅处理协议与调度调度循环，业务决策放入领域服务，避免路由层继续膨胀。
- **统一状态源**：账本、脚本仓储、执行仓储默认使用同一容器实例，杜绝测试或多会话间状态“错位”问题。
- **文档对齐**：清理文档中对已弃用实现（例如“后台任务已完整实现”）的描述，补充新的依赖注入/队列说明。

## 核心设计

1. **服务容器 `ServiceContainer`**
   - 启动时构建，托管以下依赖：`Settings`、脚本仓储、执行仓储、账本、执行调度器、事件总线、执行用例服务等。
   - 存放于 `app.state.container`，通过 `Request` 级依赖注入获取。
   - 支持测试时快速重置或替换依赖（例如传入模拟仓储）。

2. **执行域组件**
   - `ExecutionOrchestrator`：聚合校验、扣费、持久化与派发，返回领域结果 DTO。
   - `ExecutionValidator`：负责脚本存在性、版本、授权校验。
   - `BillingPort` / `DispatchPort` / `EventPublisherPort`：定义最小交互接口，适配具体实现（账本、内存队列、PubSub）。
   - `ExecutionRepository`：保留接口，默认仍使用内存实现，允许日后无缝替换为数据库/Redis。

3. **WebSocket 与后台任务**
   - WebSocket 层仅解析/封包，业务处理委托给容器中的 orchestrator/dispatcher。
   - `WorkerManager` 负责循环遍历设备队列并触发派发；空转逻辑将替换为真实调度。
   - 心跳、ACK 处理等逐步迁移至独立的 handler/dispatcher 辅助类。

## 文档清理与更新

- `docs/server/overview.md`：更新“关键设计”与“模块划分”，描述服务容器与执行域拆分。
- `docs/server/rest_api.md`：对 `POST /api/executions` 返回字段进行校验，补充新的错误码说明（如新引入的验证错误）。
- `docs/server/websocket.md`：删除“当前已实现完整派发循环”的表述，改为描述新的 handler/dispatcher 协作方式。
- `docs/server/background_tasks.md`：替换“占位实现”描述，列出新的调度循环职责与可配置项。
- 其他引用旧 `get_*` 单例的文档需同步改写。

## 测试与回归

- 重写现有 `reset_*` 帮助函数，改为使用容器实例的 `reset()` 方法，防止测试状态外泄。
- 增补执行域单元测试：验证校验失败路径、扣费失败、事件发布等。
- 保持 HTTP 端到端测试覆盖，必要时更新夹具以使用新的注入接口。

## 推进节奏

1. 完成本方案文档与 To-Do（已在 `docs/server/iteration_todo.md` 补充 T15/T16）。
2. 落实代码层依赖注入重构与执行域拆分。
3. 更新测试与文档、清理过期内容。
4. 与 NovaDesk/NovaAgent 团队同步新的运行时结构与调试方法。

执行过程中若出现额外依赖或风险，请先更新本方案与 To-Do，再开展实现。

# NovaDesk 架构重构计划

> 目标：缓解桌面端在跨端联调场景下的分层膨胀与事件耦合问题，提升 NovaDesk 与 NovaServer/NovaAgent 协作时的可维护性与扩展性。

## 背景与痛点

- 现有 `AppEventBus` 承担所有事件广播，缺乏特性边界，任何 Server 推送或本地合成事件都会落在一个流上，导致依赖链条冗长、调试困难。
- `application` 层同时承载业务编排、平台调用（ADB、文件系统）与 UI 协调逻辑，违背全局 `domain/application/data/platform` 分层约束。
- 设备流程（合并、缓存、状态推送）与联调关注点杂糅，难以沉淀跨组件契约或在 NovaServer/NovaAgent 变更时保持最小改动面。
- 模块导航与权限等横切逻辑集中在少量控制器内，后续迭代易产生“超级控制器”。

## 总体策略

1. **分层重塑**：明确 `domain` 暴露的用例与事件契约，`application` 层只负责调度与状态管理，`data`/`platform` 提供实现。
2. **事件解耦**：按特性建立独立事件通道（起步于设备域），逐步替换全局广播；Server 推送 → 领域事件 → 控制器，仅保留必要的跨域桥接。
3. **跨端契约统一**：提取对 NovaServer/NovaAgent 的协议定义，避免在多个层级重复解析同一 payload。
4. **迭代式实施**：先完成设备域“竖切”重构，再复制模式到执行、模板等模块；每阶段保持编译与主要测试通过。

## 分阶段计划

### 当前迭代聚焦

- 对齐 PC 端 WebSocket topic 契约（`agents.status`、`executions.progress`、`executions.result`），避免与 NovaServer 的最新实现脱节。
- 在事件映射处补充单元测试，为后续分层重构提供安全网。

### Phase 1：设备域拆分

- 新增 `domain/events/device_event.dart`、`domain/ports/device_event_sink.dart` 定义领域事件与发布接口。
- 引入 `DeviceEventBus`（Infrastructure 实现），提供 `publish()` / `stream`，供 `DeviceSyncCoordinator`、`PcWebSocketService`、`DeviceController` 使用。
- `DeviceSyncCoordinator` 只负责调度与合并结果，输出 `DeviceSyncCompleted` 事件；去除与 UI 直接耦合的 `AppEventBus`。
- `DeviceController` 订阅设备事件通道，维护 `DeviceState`；对其它模块隐藏实现细节。
- 更新依赖注入（`Bootstrap`、`app_providers.dart`），确保新通道贯通并保留原有 Connection/Execution 事件。
- 扩充单测覆盖新的事件流（重点覆盖合并结果、缓存加载、控制器状态更新）。

### Phase 2：协议契约抽象

- 将 `CoreEvent` 中与设备相关的 payload 映射抽离到 `domain/contracts`，并与 NovaServer/NovaAgent 文档对齐。
- `PcWebSocketService` 仅负责反序列化与契约校验，再交给相应领域事件通道。
- 为执行、计费等 topic 预留扩展接口，为后续模块拆分做准备。

### Phase 3：其它特性迁移

- 按执行、模板、日志等模块复制 Phase 1 模式，建立独立的 use case + event sink。
- 将“管理员工具/导航”控制器拆分为功能模块，利用角色能力服务驱动 UI。
- 清理遗留的 AppEventBus 依赖，最终只保留连接状态或跨域通知。

### Phase 4：整理与文档沉淀

- 更新 `docs/desktop/*` 与 `docs/flows/*`，记录新分层与事件流。
- 输出跨端联调基线（契约、测试脚本、故障排查指南），交付给 Server/Agent 团队共用。

## 交付物与验收指标

- **代码**：模块化事件通道、重构后的控制器与服务、补充单元测试。
- **文档**：本计划、更新后的 `overview.md`/`device_management.md` 等。
- **验证**：`flutter test` 通过，设备列表刷新/WS 推送功能正常，日志输出覆盖关键路径。

## 时序安排（建议）

| 时间 | 里程碑 |
| --- | --- |
| D0-D1 | 完成 Phase 1 实现与测试 |
| D2 | 衔接 Phase 2 契约抽象，协调 Server/Agent |
| D3-D4 | Phase 3 模块迁移（按优先级滚动） |
| D5 | Phase 4 文档/回归收尾，准备合并 |

---

本计划随实施滚动更新（重大调整需在 `docs/desktop/todo.md` 与 PR 描述同步）。

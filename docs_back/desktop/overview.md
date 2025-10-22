# NovaDesk 桌面端设计

NovaDesk 使用 Flutter 3.x 构建，在 Windows/macOS 桌面环境运行。主要职责：账号登录、PC/设备标识管理、脚本模板创建、执行任务发起、执行结果展示、调用 Server 查询消费数据。

## 分层结构

| 层 | 包 | 说明 |
| --- | --- | --- |
| 表现层 | `presentation` | 路由、页面、小部件、特性状态读取（Riverpod/BLoC） |
| 应用层 | `application` | 调度用例、协调状态管理与依赖注入，不直接依赖平台实现 |
| 领域层 | `domain` | 跨端契约、实体、用例接口与领域事件（`usecases/`、`entities/`、`events/`） |
| 数据层 | `data` | REST/WS 客户端、Repository 实现、缓存（依赖领域接口） |
| 平台服务 | `platform` | ADB 操作、文件系统访问、系统通知等底层能力 |

## 启动流程

1. 启动时检查是否已有 NovaDesk 进程在运行（基于本地互斥锁/IPC 文件），若存在则提醒用户并退出。当前实现采用 `config/.nova_desk.lock` 文件，通过 `File.openSync(mode: FileMode.write)` + `LockFile`（Unix）/`RandomAccessFile.lockSync()`（Windows）持有独占锁，应用退出时释放并删除；异常退出时下次启动需检测陈旧锁并提示用户手动处理。
2. 初始化配置 → 读取/生成 `pcId`（存储在运行目录 `config/pc.json`）。若文件缺失则生成 UUIDv4 并写入；若存在则加载并校验 `clientVersion`，必要时执行迁移逻辑（在 `config/migrations/` 中维护脚本）。
3. 启动 ADB 设备扫描任务（定时与手动刷新）。
4. 检查本地模板目录结构（`templates/`），若不存在则创建；同时确保目录权限为当前用户可读写。
5. 打开登录页；成功后缓存 JWT，并建立 WS 连接监听 Server 推送。
6. 加载脚本列表、已购状态、在线设备列表，合并本地扫描结果生成 UI。

### 单实例守护

- 封装 `SingleInstanceGuard` 服务，对外暴露 `Future<GuardHandle> acquire()`。Guard 内部负责：
  - 计算运行目录下锁文件路径（默认 `config/.nova_desk.lock`，可通过配置覆盖）。
  - 针对 macOS/Linux 调用 `RandomAccessFile.lockSync(exclusive: true)`；Windows 使用 `File.lockSync()`；若锁已被持有，则返回失败结果供 UI 提示“已有实例在运行”。
  - 监听 `ProcessSignal.sigint`/`sigterm`（桌面端通过 `onExit` 钩子）在应用退出时释放锁。
- Guard 获取失败时直接终止启动流程，避免继续初始化导致多实例控制同一设备。
- Guard 的日志写入 `logs/app.log`，便于排查锁文件占用问题。

### `pcId` 初始化

- 封装 `PcIdentityService` 读取/写入 `config/pc.json`，对外提供：
  - `Future<PcIdentity> loadOrCreate({String? overridePcId})`
  - `Future<void> updateLastLogin(DateTime timestamp)`
- `pcId` 使用 `uuid` 包生成，写入时同步持久化 `createdAt`、`lastLoginAt`、`clientVersion`。
- 若检测到文件损坏或字段缺失，需抛出明确错误并提示用户备份/重置；默认回退策略是在备份旧文件后生成新的 `pcId`。

## 状态管理建议

- 状态容器使用 Riverpod（推荐）或 BLoC，定义全局 `AppState` 聚合下列切片：
  - `authState`: 登录信息、token、用户/租户；
  - `pcState`: `pcId`、本地产生的系统信息；
  - `deviceState`: 本地扫描结果 + 服务器在线状态；
  - `scriptState`: 脚本列表、购买状态；
  - `executionState`: 当前执行、历史查询结果；
  - `templateState`: 本地模板缓存。
- 特性事件以“领域事件通道”对外暴露，例如 `DeviceEventBus`、`ExecutionEventBus`（进行中），UI 仅订阅自身模块的事件流。
- WebSocket 推送由 `PcWebSocketService` 解析为 `CoreEvent`，再交给对应领域事件通道，避免全局广播；应用层仅协调订阅关系。
- 每个切片维护 `state` + `controller` + `selector` 套件，Controller 调用领域用例并更新状态，Selector 提供只读视图给 UI。
- 对于需要持久化的状态（模板、缓存），Controller 在变更后同步调用数据层 Repository 写入文件。
- 所有状态更新需记录结构化日志，便于回溯（可复用 `AppLogger`）。

## 模块导航与角色控制

- 桌面端主导航采用统一的 `ShellScaffold`，根据用户 `role` 决定可见模块。模块标识建议集中管理在 `presentation/navigation/modules.dart`：
  - `dashboard`
  - `devices`
  - `scripts`
  - `executions`
  - `billing`
  - `adminTools`（新增）
- 权限策略：
  - `SUPER_ADMIN`：可见全部模块。
  - `ADMIN`：与 `SUPER_ADMIN` 相同，但部分超级管理员专属操作（如租户管理）在 Admin Tools 内隐藏或标记为不可用。
  - `USER`：仅展示 `dashboard`/`devices`/`scripts`/`executions`，对 `billing`（个人视图）与 `adminTools` 隐藏。
- 导航刷新逻辑：
  1. 登录成功后解析 JWT payload，构建 `RoleCapabilities`。
  2. 将角色能力写入 `AppState.authState.capabilities`。
  3. `NavigationController` 根据能力生成模块列表，驱动侧边栏与路由守卫。
- Admin Tools 模块职责：
  - Agent 包管理：上传新版本 APK、查看历史版本、标记当前发行版本。
  - 后续可扩展租户管理、联调诊断等功能。
- Admin Tools 服务封装：
  - 新增 `AdminToolsService`（数据层）调用 Server `/api/admin/agent-packages` 接口。
  - `AdminToolsController`（应用层）管理上传进度、表单校验、状态缓存。
  - UI 遵循 `presentation/admin_tools/` 目录结构，提供文件选择、版本/发布说明输入及上传结果反馈。
- 日志要求：所有上传操作需在 `AppLogger` 中记录 `role`、`versionName`、`fileChecksum`，失败时附详细错误码，便于审计。

## 网络客户端

- dio 配置：
  - 基础 URL、超时、重试策略。
  - 拦截器注入 JWT、traceId。
  - 错误统一处理（余额不足、未授权等）。
- WebSocket：
  - 建立 `ws/pc` 连接，支持断线重连。
  - 解析消息 envelope，按 topic 分发至对应处理器。

## ADB 服务

- 封装成 `AdbService`：
  - `listDevices()`：返回 `deviceId`、设备名称、在线标记；
  - `installAgent(apkPath)`、`startAgent(params)`；
  - `stopAgent(deviceId)`（可选，触发 `adb shell am force-stop`）。
- 允许替换实现，默认空操作以便开发时模拟。

详细的设备管理、模板管理与界面流程见本目录其他文档。

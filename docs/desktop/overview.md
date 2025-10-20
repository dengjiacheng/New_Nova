# NovaDesk 桌面端设计

NovaDesk 使用 Flutter 3.x 构建，在 Windows/macOS 桌面环境运行。主要职责：账号登录、PC/设备标识管理、脚本模板创建、执行任务发起、执行结果展示、调用 Server 查询消费数据。

## 分层结构

| 层 | 包 | 说明 |
| --- | --- | --- |
| 表现层 | `presentation` | 路由、页面、小部件、状态管理（推荐使用 Riverpod/BLoC） |
| 应用层 | `application` | 用例封装：登录、设备同步、执行脚本、查询结果 |
| 数据层 | `data` | REST/WS 客户端（dio + web_socket_channel），本地存储（模板/pcId） |
| 平台服务 | `platform` | ADB 操作、文件系统访问、系统通知 |

## 启动流程

1. 启动时检查是否已有 NovaDesk 进程在运行（基于本地互斥锁/IPC 文件），若存在则提醒用户并退出。
2. 初始化配置 → 读取/生成 `pcId`（存储在运行目录 `config/pc.json`）。
2. 启动 ADB 设备扫描任务（定时与手动刷新）。
3. 检查本地模板目录结构（`templates/`），若不存在则创建。
4. 打开登录页；成功后缓存 JWT，并建立 WS 连接监听 Server 推送。
6. 加载脚本列表、已购状态、在线设备列表，合并本地扫描结果生成 UI。

## 状态管理建议

- 使用全局 `AppState`（Riverpod/Provider），包含：
  - `authState`: 登录信息、token、用户/租户；
  - `pcState`: `pcId`、本地产生的系统信息；
  - `deviceState`: 本地扫描结果 + 服务器在线状态；
  - `scriptState`: 脚本列表、购买状态；
  - `executionState`: 当前执行、历史查询结果；
  - `templateState`: 本地模板缓存。
- WebSocket 事件通过 Stream Provider 注入，驱动 UI 实时更新。

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

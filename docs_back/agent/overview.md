# NovaAgent 架构概述

NovaAgent 是运行在 Android 设备上的 Instrumentation Runner，负责接收 NovaServer 下发的执行指令，运行内置脚本并回传结果。采用 Kotlin/Java 编写，基于 `AndroidJUnitRunner` 和 UiAutomator。

## 模块划分

| 模块 | 说明 |
| --- | --- |
| `core.boot` | 引导层（`AgentKernel`）负责装配配置、WebSocket 客户端、Reporter、执行协调器、持久化队列 |
| `core.ws` | WebSocket 客户端（OkHttp），消息收发、ACK 回执与重连 |
| `core.registry` | 脚本目录注册、参数 schema 维护 |
| `execution.runner` | 执行协调器、任务状态机 |
| `execution.actions` | 脚本动作封装（UiAutomator、IME、OpenCV 占位） |
| `execution.scripts` | 内置脚本实现（按 `scriptId` 分类） |
| `reporting` | 日志记录、截图、结果打包 |
| `diagnostics` | 心跳指标采集（CPU、内存、最近任务） |

## 技术栈

- **AndroidX Test Runner**：自定义 Runner 扩展 `onStart`.
- **OkHttp WebSocket**：与 Server 建立持久连接。
- **Gson/Moshi**：JSON 序列化。
- **Coroutine/Handler**：调度执行流程（如使用 Kotlin）。
- **Optional**：OpenCV（AAR 占位）、自研 IME 框架（暂未实现）。

## 启动参数

Agent 通过 `adb shell am instrument` 启动，参数以 JSON 传入：

```json
{
  "serverUrl": "https://api.example.com",
  "agentWs": "wss://api.example.com/ws/agent",
  "token": "<device-token>",
  "tenantId": "TEN-001",
  "userId": "USR-789",
  "pcId": "PC-123",
  "deviceId": "emulator-5554"
}
```

启动流程：
1. Runner 解析参数并构造 `AgentConfig`（脚本目录通过 `ScriptCatalogProvider` 生成）。
2. 创建 `AgentKernel`，该内核会注入 `AgentWebSocketClient`、Reporter、执行协调器与持久化 Reporter 队列，并立即启动连接。
3. 注册成功并收到 ACK 后，内核会重放历史未确认事件，随后进入 `IDLE` 状态等待 NovaServer 指令。

详细生命周期、指令处理见本目录其他文档。

## 构建与部署（Android 仿真）

- **工程结构**：`NovaAgent` 目录拆分为 `core/`（平台无关逻辑、WS、命令解析等）与 `app/`（Android Instrumentation Runner）。`core` 依旧支持 `./gradlew :core:test` 运行纯 Kotlin 单测。
- **构建命令**：
  ```bash
  cd NovaAgent
  ./gradlew :app:assembleDebug
  ```
  生成的 APK 位于 `app/build/outputs/apk/debug/app-debug.apk`。
- **安装至模拟器 / 真机**：
  ```bash
  adb install -r app/build/outputs/apk/debug/app-debug.apk
  ```
- **启动 Runner**：依照业务网关参数执行 Instrumentation：
  ```bash
  adb shell am instrument -w \
      -e serverUrl "https://api.example.com" \
      -e agentWs "wss://api.example.com/ws/agent" \
      -e token "<device-token>" \
      -e tenantId "TEN-001" \
      -e userId "USR-001" \
      -e pcId "PC-001" \
      -e deviceId "emulator-5554" \
      com.nova.agent/com.nova.agent.instrumentation.NovaInstrumentation
  ```

# NovaAgent 架构概述

NovaAgent 是运行在 Android 设备上的 Instrumentation Runner，负责接收 NovaServer 下发的执行指令，运行内置脚本并回传结果。采用 Kotlin/Java 编写，基于 `AndroidJUnitRunner` 和 UiAutomator。

## 模块划分

| 模块 | 说明 |
| --- | --- |
| `core.boot` | 启动入口、启动参数解析、WS 连接建立 |
| `core.ws` | WebSocket 客户端（OkHttp），消息收发与重连 |
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
1. Runner 解析参数，初始化配置。
2. 建立 WS 连接并发送 `REGISTER` 消息（含脚本目录）。
3. 进入待命状态，等待 `EXECUTE` 指令。

详细生命周期、指令处理见本目录其他文档。

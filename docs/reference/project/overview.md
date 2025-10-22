---
title: Nova 平台项目总览
status: active
updated_at: 2025-10-22
dcp: TASK-20251022-1732-ONBRD
---

# Nova 平台项目总览

Nova 项目由三大子系统组成：

- **NovaServer**（Python/FastAPI）：云端控制面，负责身份认证、任务调度、脚本分发与 websocket 双向通信。
- **NovaAgent**（Android/Kotlin）：运行在桌面代理或终端上的常驻进程，负责与云端保持长连、执行脚本并上报状态。
- **NovaDesk**（Flutter 桌面）：运营控制台，提供设备监控、脚本编排与资产管理界面。

## 关键职责映射

| 模块 | 核心职责 | 关键目录 | 关键依赖 |
| ---- | -------- | -------- | -------- |
| NovaServer | API/WS 网关、调度、资产管理 | `NovaServer/app/{api,services,workers}` | FastAPI, SQLAlchemy, AsyncPG |
| NovaAgent | Agent 引导、执行链路、可靠上报 | `NovaAgent/core/src/main/kotlin/com/nova/agent` | Kotlin Coroutines, OkHttp, Moshi |
| NovaDesk | 桌面 UI、设备与脚本管理 | `NovaDesk/lib` | Flutter, Riverpod, Dio |

## 环境与运行

- **后端**：Python ≥ 3.10，使用 `uvicorn` 部署；数据库接口抽象在 `app/db`，默认异步 PostgreSQL。
- **Agent**：Android SDK 34、Kotlin 1.9+，包含自定义 `InstrumentationRunner` 以支持端到端测试。
- **桌面端**：Flutter 3.3+，桌面目标（macOS/Windows）启用 `file_picker` 与本地守护接口。

## 自动化与守护

- `.codex` 目录定义零指令守护流程：创建 DCP、按模块拆分 PR、记录 ledger。
- `autopilot-local/watch_auto.js` 负责监听文档/代码变更并触发对应分支与 PR。
- CI 入口位于 `.github/workflows/ci-matrix.yml`，按路径过滤触发多栈测试。

## 接手后优先事项

1. 统一应用配置与密钥管理，补齐环境说明（DEV/QA/PROD）；
2. 完成权限矩阵与多端通信协议文档；
3. 设立季度依赖升级窗口与回归清单；
4. 落地可观测性指标（Agent 在线率、任务成功率、脚本执行时长）。

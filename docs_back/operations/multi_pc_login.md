# 多端登录策略

## 目标

- 同一账号可在多台 PC 同时登录。
- Server 能区分每个 PC 的设备与执行来源。
- 避免同一设备被多个 PC 同时控制造成冲突。

## `pcId` 管理

- NovaDesk 首次登录生成 `pcId`，写入 `config/pc.json`，后续所有 REST/WS 请求均携带。
- 重装或清空数据 → 新 `pcId`。
- Server 接收请求时记录 `pcId`，审计日志/交易记录都冗余该字段。

## 单机单实例

- NovaDesk 启动时通过互斥锁或守护进程检查是否已有实例运行（例如基于文件锁/Named Mutex）。
- 发现已有实例则提示用户并退出，确保同一物理 PC 同时只运行一个 NovaDesk，避免同时控制相同设备或重复生成 `pcId`。
- 若需要切换账号，须在该实例中注销后重新登录；不支持同机多开。

## 设备所属关系

- Agent 注册时携带 `pcId`。Server 在内存表记录：
  ```json
  {
    "tenantId": "...",
    "userId": "...",
    "pcId": "PC-123",
    "deviceId": "emulator-5554",
    "status": "ONLINE"
  }
  ```
- PC 端合并本地 ADB 列表与 Server 在线列表时，比较 `pcId`：
  - 一致：显示为“上线”。
  - 不一致：显示为“被其他 PC 占用”，可提示占用 `pcId`。

## 设备争用策略

选项 A（默认）：后上线覆盖前上线  
1. Server 收到新的 Agent 注册，发现相同 `deviceId` 但 `pcId` 不同。  
2. Server 向旧连接发送 `FORCE_DISCONNECT`，再接受新连接。  
3. 通知所有 PC 设备所属发生变化。

选项 B：拒绝  
1. Server 返回错误 `DEVICE_IN_USE`，新 Agent 需退出。  
2. PC 提示用户在原 PC 下线后再上线。

策略可配置，默认选项 A（更贴近用户操作体验）。

## 执行冲突避免

- Server 对每个 `deviceId` 维护执行锁，队列内一次只能有一个 `RUNNING` 任务。
- 当其他 PC 提交同一设备任务时，会进入排队；在队列事件中可标记来源 `pcId`。

## 通知与可见性

- 当同账号在新 PC 登录时，Server 可推送 `system.notice`：
  ```
  [系统通知] 新 PC 登录：PC-123 (macOS 13.4, 2024-06-01 10:00)
  ```
- 提供 REST 接口 `GET /api/session/clients`（可选）查看当前账号活跃 PC 列表。
- 用户可在 PC 上选择“踢出其他终端”（调用 Server API 删除 session）。

## 审计

- 审计日志记录 `pcId`，包含登录、脚本执行、购买等操作来源。
- 帮助定位问题：若某执行失败，可追溯发起的 PC。

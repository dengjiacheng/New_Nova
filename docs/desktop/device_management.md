# 设备管理设计

NovaDesk 需在本地维护设备列表并与 Server 在线状态对齐。本地与云端不直接共享存储，通过 `pcId + deviceId` 关联。

## 数据结构

```dart
class LocalDevice {
  final String deviceId;        // ADB serial
  final String? alias;          // 用户自定义别名（可选）
  final DeviceStatus status;    // OFFLINE / STARTING / ONLINE / STOPPING
  final bool serverOnline;      // 来自 Server 的在线标记
  final AgentInfo? agentInfo;   // Server 公布的 Agent 信息
}
```

- `status` 表示本地视角，`serverOnline` 表示云端视角。
- `AgentInfo` 含 `agentVersion`、`scriptCatalog`、`lastHeartbeat`、`currentExecution`。

## 列表生成流程

1. `AdbService.listDevices()` 返回本地设备数组。
2. REST `GET /api/devices` 返回云端在线设备集合。
3. 合并规则：
   - 若本地有设备但 Server 无，状态 `OFFLINE`；
   - 若双方都有且匹配 `pcId` → 状态 `ONLINE`；
   - 若 Server 有记录但 `pcId` 不匹配 → 提示“设备被其他 PC 占用”。
4. UI 显示：
   - 在线状态（绿/灰）；
   - 当前任务（来自 `AgentInfo.currentExecution`）。

## 上线/下线操作

### 上线
1. 用户点击“上线” → 触发 `DeviceController.start(deviceId)`。
2. 控制器步骤：
   - 切换状态 `STARTING`；
   - 执行 `installAgent`（视版本情况）；
   - 构造启动参数 JSON，写入临时文件/`am start` 参数：
     ```json
     {
       "serverUrl": "https://api.example.com",
       "agentWs": "wss://api.example.com/ws/agent",
       "token": "<deviceToken>",
       "tenantId": "...",
       "userId": "...",
       "pcId": "PC-123",
       "deviceId": "emulator-5554"
     }
     ```
   - `adb shell am start -n <agentPackage>/<Runner> --es args '<json>'`
3. 监听 Server 推送的 `REGISTER` 成功事件，将状态改为 `ONLINE`。
4. 超时未上线 → 恢复为 `OFFLINE` 并提示错误日志。

### 下线
1. 用户点击“下线” → 先尝试本地执行 `adb shell am force-stop` 停止 Agent（可配置是否同时调用 Server API）。
2. 亦可调用 `POST /api/devices/{deviceId}/stop`，让 Server 向 Agent 发送 `SHUTDOWN` 命令。
3. Agent 断开后，Server 推送离线事件，客户端更新状态。

## 错误处理

- ADB 失败：捕获异常，展示错误消息，并恢复状态。
- Server 判定 `pcId` 不匹配：停止本地 Agent，提示用户关闭另一台 PC。
- Agent 心跳超时：Server 推送下线事件；UI 显示红色 ⚠ 提醒用户检查设备。

## 多 PC 并行

- 每台 PC 维持独立设备列表。
- 当 Server 推送其他 PC 上线的同一 `deviceId`，当前 PC 应提示“占用中”。
- 若用户强制上线，可提供“夺取控制”功能：调用专门 API 断开旧连接并覆盖（需谨慎设计）。

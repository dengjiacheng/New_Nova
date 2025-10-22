# 本地存储与配置

## 目录结构（相对运行目录）

```
config/
  pc.json            // 存储 pcId、版本信息、首次登录时间
  .nova_desk.lock    // 单实例互斥锁（运行时存在，退出时删除）
  migrations/        // 版本迁移脚本（可选）
logs/
  app.log            // 本地日志（可选）
templates/
  <scriptId>/
    <template>.json  // 参数模板
cache/
  devices.json       // 最近一次合并的设备状态（可选）
  scripts.json       // 最近一次脚本列表快照（可选）
```

## `config/pc.json`

```json
{
  "pcId": "PC-1dcae46e-0b71-4eb9-9b13-6bc74606c8f2",
  "createdAt": "2024-06-01T09:00:00Z",
  "lastLoginAt": "2024-06-02T08:30:00Z",
  "clientVersion": "0.1.0"
}
```

- 首次启动：不存在则创建；`pcId` 使用 UUIDv4 生成。
- 清空或重装后会生成新文件。
- `lastLoginAt` 可在登录成功后更新，便于支持多终端管理。
- 读取/写入由 `PcIdentityService` 统一处理，负责字段补全、备份旧版本（`pc.json.bak-<timestamp>`）与迁移。

## 模板目录安全

- 模板文件可能包含敏感信息（如密码）。建议：
  - 默认文件权限设置为仅当前用户可读写；
  - 提供“清空敏感数据”选项（执行后将某些字段置空）。

## 缓存策略

- `devices.json`、`scripts.json` 可选，仅用于加快启动时 UI 渲染；成功拉取最新数据后应覆盖缓存。
- 缓存文件结构示例：
  ```json
  {
    "updatedAt": "2024-06-01T12:00:00Z",
    "data": [ ... ]
  }
  ```

## 日志

- 本地日志默认保留最近若干文件（轮转），用于排查 ADB、网络问题。
- 日志级别可配置：`INFO`/`DEBUG`。敏感数据需脱敏。
- 单实例守护的锁事件、异常均写入 `logs/app.log`，便于分析锁未释放的情况；若检测到陈旧锁文件且无进程占用，应提示用户清理后重试。

## 配置项

- `config/app.yaml`（可选）：记录 Server 地址、代理设置、ADB 可执行路径。
- 提供 UI 让用户修改 Server 地址（例如切换测试环境），修改后重新启动。

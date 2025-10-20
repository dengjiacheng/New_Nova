# 配置与部署指南

## 环境依赖

- Python 3.11+
- PostgreSQL 14+
- Redis 7+
- Node/Flutter（供 NovaDesk 构建）
- Android SDK（供 NovaAgent 构建/签名）
- Nginx/OpenResty（HTTPS/WSS 反向代理）

## 配置项清单

使用 `.env` 或配置文件管理：

| 键 | 说明 |
| --- | --- |
| `DATABASE_URL` | PostgreSQL 连接串 |
| `REDIS_URL` | Redis 连接 |
| `JWT_SECRET` | JWT 签名秘钥 |
| `JWT_EXPIRE_MINUTES` | Token 默认有效期 |
| `DEVICE_TOKEN_SECRET` | Agent token 生成秘钥 |
| `API_BASE_URL` | Server 公开地址 |
| `HEARTBEAT_INTERVAL` | Agent 心跳间隔（秒） |
| `HEARTBEAT_TIMEOUT` | 心跳判定超时 |
| `EXECUTION_TIMEOUT_DEFAULT` | 默认执行超时（毫秒） |
| `AUDIT_HOT_RETENTION_DAYS` | 审计热存储天数 |
| `ARCHIVE_BUCKET` | 归档存储桶地址 |
| `ASSET_BUCKET` | 执行附件临时存储桶 |
| `ASSET_TTL_HOURS` | 附件有效期（小时） |
| `BALANCE_LOW_THRESHOLD` | 余额预警阈值 |

## 部署步骤（Server）

1. 安装依赖并创建虚拟环境。
2. 执行 Alembic 迁移：`alembic upgrade head`。
3. 初始化超级管理员与默认脚本数据（管理脚本）。
4. 运行 Uvicorn/Hypecorn：`uvicorn main:app --host 0.0.0.0 --port 8000`.
5. 配置 systemd 或 Supervisor 保证服务常驻。
6. 部署 Nginx：
   - 监听 443，反代到 Uvicorn 8000。
   - 配置 WebSocket：`proxy_set_header Upgrade $http_upgrade;`.
   - 强制 HTTPS，启用 HTTP/2。

## 部署步骤（NovaDesk）

- 使用 Flutter Desktop 构建：
  - Windows：`flutter build windows`
  - macOS：`flutter build macos`
- 打包时将默认 `config/app.yaml` 写入，可包含默认 Server 地址。
- 提供自动更新机制（可选）。

## 部署步骤（NovaAgent）

- 使用 Gradle 构建 Release APK。
- 配置签名证书；输出文件供 PC ADB 安装。
- 可在内网搭建 APK 更新服务，NovaDesk 检查 Agent 版本并提示更新。

## 监控与日志

- Server：
  - 应用日志（JSON），写入 ELK 或 Loki。
  - Metrics：Prometheus（心跳延迟、任务成功率、消费速率）。
- Redis、PostgreSQL 监控。
- Nginx 访问日志分析。

## 安全建议

- 所有对外接口必须启用 TLS。
- JWT 秘钥、数据库密码存于安全密钥管理工具（Vault/SSM）。
- 限制 Agent token 使用范围（按租户/设备生成，定期轮换）。
- 对外开放接口需做速率限制（Nginx/Lua/OpenResty）。

## 备份与恢复

- PostgreSQL：每日备份 + WAL 归档。
- Redis：启用 AOF；关键数据（在线设备）可丢失，备份主要针对队列未消费数据。
- 审计归档：对象存储多副本。

## 灰度与环境

- 建议建立 `dev`、`staging`、`prod` 三套环境。
- Agent 可通过启动参数切换 Server 地址。
- NovaDesk UI 提供环境切换选项，仅对内部用户开放。

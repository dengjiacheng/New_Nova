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

| 键                          | 说明                 |
| --------------------------- | -------------------- |
| `DATABASE_URL`              | PostgreSQL 连接串    |
| `REDIS_URL`                 | Redis 连接           |
| `JWT_SECRET`                | JWT 签名秘钥         |
| `JWT_EXPIRE_MINUTES`        | Token 默认有效期     |
| `DEVICE_TOKEN_SECRET`       | Agent token 生成秘钥 |
| `API_BASE_URL`              | Server 公开地址      |
| `HEARTBEAT_INTERVAL`        | Agent 心跳间隔（秒） |
| `HEARTBEAT_TIMEOUT`         | 心跳判定超时         |
| `EXECUTION_TIMEOUT_DEFAULT` | 默认执行超时（毫秒） |
| `AUDIT_HOT_RETENTION_DAYS`  | 审计热存储天数       |
| `ARCHIVE_BUCKET`            | 归档存储桶地址       |
| `ASSET_BUCKET`              | 执行附件临时存储桶   |
| `ASSET_TTL_HOURS`           | 附件有效期（小时）   |
| `AGENT_PACKAGE_STORAGE_DIR` | Agent APK 本地存储目录（Server 写入路径，默认 `storage/agent-packages`，Service 会在该目录中保存上传的 APK） |
| `BALANCE_LOW_THRESHOLD`     | 余额预警阈值         |

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

### 使用部署脚本

仓库提供两份示例脚本便于快速上线：

- `scripts/deploy.sh`：同步整个仓库并配置 systemd，依赖 `rsync`。
- `scripts/deploy_server.sh`：仅传输 `NovaServer`，会先停止旧服务并清空 `${REMOTE_DIR}/NovaServer`，依赖 `tar`/`ssh`。

使用前可按需配置环境变量：

```bash
export REMOTE_HOST="root@120.26.30.221"  # 必填
export SSH_PORT=22                       # 默认 22，可省略
export SSH_PASSWORD="请替换为真实密码"   # 建议改用 SSH key
export REMOTE_DIR="/opt/nova"            # 默认 /opt/nova
export PYTHON_BIN="python3.11"           # 默认 python3.11，可自定义
```

执行脚本：

```bash
./scripts/deploy.sh          # 全量同步
./scripts/deploy_server.sh   # 仅部署 NovaServer
```

> 若设置 `SSH_PASSWORD`，需提前安装 `sshpass`。建议改用 SSH Key 以提升安全性。

### 初始化默认账号

完成数据库迁移（`alembic upgrade head`）后，可执行 `scripts/init_admin.py` 初始化默认租户与管理员：

```bash
# 可在本地或服务器上运行，确保能访问数据库
python3 scripts/init_admin.py \
  --database-url "postgresql+asyncpg://nova:nova@localhost:5432/nova" \
  --tenant-name "Demo Tenant" \
  --username demo \
  --password demo123
```

脚本会在数据库中创建租户、余额记录与管理员账号；如账号已存在则跳过。

## 部署步骤（NovaDesk）

- 使用 Flutter Desktop 构建：
  - Windows：`flutter build windows`
  - macOS：`flutter build macos`
- 打包时将默认 `config/app.yaml` 写入，可包含默认 Server 地址。
- 提供自动更新机制（可选）。

## 部署步骤（NovaAgent）

- 使用 Gradle 构建 Release APK，并通过 `./gradlew :app:bundleRelease` 生成签名产物。
- 构建完成后由拥有 `ADMIN`/`SUPER_ADMIN` 权限的成员在 NovaDesk Admin Tools 中上传：
  - 选择 APK 文件并填写版本信息，系统会调用 `POST /api/admin/agent-packages`（见 `docs/server/rest_api.md#7-agent-包管理`）写入 Server。
  - 上传成功即刻生成版本历史记录，可在同一页面设置激活版本。
- PC 端 ADB 安装逻辑读取 `GET /api/agent-packages/latest`，若检测到版本号差异则提示管理员更新。
- 仍需保留离线安装流程作为兜底（下载签名 URL 后手动 `adb install`）。

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

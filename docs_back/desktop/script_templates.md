# 脚本模板管理

脚本模板仅存在于 PC 本地，用于为预置脚本配置参数值。执行时 NovaDesk 将模板数据序列化为参数快照一并提交 Server。

## 存储结构

- 根目录：`templates/`
- 脚本子目录：`templates/<scriptId>/`
- 模板文件：`templates/<scriptId>/<templateName>.json`
- 文件格式：
```json
{
  "templateId": "local-uuid",
  "name": "默认登录",
  "description": "常规账号登录",
    "version": 1,
    "fields": [
      { "key": "username", "type": "string", "label": "用户名", "value": "demo" },
    { "key": "password", "type": "password", "label": "密码", "value": "******" },
    { "key": "timeout", "type": "number", "label": "超时(秒)", "value": 60 },
    { "key": "templateImage", "type": "file", "label": "匹配模板", "value": "/Users/demo/Pictures/login.png" }
  ],
  "metadata": {
    "createdAt": "2024-06-01T12:00:00Z",
    "updatedAt": "2024-06-01T12:05:00Z"
  }
  }
  ```

## 模板生命周期

1. **创建**：用户在脚本详情页点击“新建模板”，选择字段类型、默认值。字段定义可由 Agent 发布的脚本元数据提供（脚本上报字段要求）。
2. **编辑**：模板列表支持编辑字段值、描述。修改时更新 `updatedAt`。
3. **复制**：允许基于现有模板复制为新模板，便于快速定制。
4. **删除**：从目录中移除文件，UI 同步更新。
5. **导入/导出**：支持将模板压缩为 `.zip` 或单个 `.json` 供备份；导入时检测 `templateId` 冲突，可生成新 ID。
6. **归档**：模板被执行后，需记录最近一次执行时间；可选提供“归档/恢复”操作隐藏旧模板。

### 模块职责

- `TemplateRepository`：统一读取/写入 `templates/` 目录，缓存最近加载的模板；提供去重、排序、归档等操作。
- `TemplateService`：封装创建/更新/复制/删除/导入导出逻辑，负责字段校验、生成 `templateId`、维护 `metadata`。
- `ExecutionAssetService`：按模板中 `file` 字段上传资产，并在执行完成或取消时负责资源释放。
- `TemplateController` / 状态管理切片：协调 UI 与服务层，处理并发修改、脏数据提示。

## 执行时参数快照

执行任务时，NovaDesk 生成 `ExecutionParameterSnapshot`：
```json
{
  "templateName": "默认登录",
  "fields": {
    "username": "demo",
    "password": "******",
    "timeout": 60
  },
  "checksum": "sha256:abcd...",
  "createdAt": "2024-06-01T12:10:00Z"
}
```

- `checksum` 用于检测模板变化。
- 该快照随执行请求发送给 Server，并记录在执行日志中。
- 密码等敏感字段在热存储中可替换为掩码。

### 二进制资源处理

- 当模板字段类型为 `file` 时，保存的是本地文件路径以及最近访问时间。
- 用户发起执行时，NovaDesk 对每个文件字段执行以下步骤：
  1. 校验文件是否存在、大小是否在允许范围内。
  2. 通过 `POST /api/executions/assets` 上传文件，获取 `assetId`、`downloadUrl`、`expiresAt`。
  3. 在执行请求的 `assets` 列表中引用 `assetId`，并在参数快照中保留字段名（值可记录为 `asset://<assetId>` 以便追踪）。
- 上传失败时应终止执行流程并提示用户；成功上传但未提交执行时，可调用资产删除接口释放资源。
- 为保护隐私，可在上传完成后提示用户是否清理本地临时文件（若有额外生成的压缩包等）。
- `ExecutionAssetService` 负责上传/删除资产与重试策略，失败后记录日志并回滚本地状态。
- 上传成功后在模板执行快照中保存 `assetChecksum`，便于重复执行时判断是否可复用历史上传结果。

## 脚本字段定义来源

- Agent 在 `REGISTER` 时同步脚本目录，附带 `parameterSchema`：
  ```json
  {
    "scriptId": "SCRIPT_LOGIN",
    "version": "1.2.0",
    "parameterSchema": [
      { "key": "username", "type": "string", "required": true, "description": "用户账号" },
      { "key": "password", "type": "password", "required": true },
      { "key": "timeout", "type": "number", "required": false, "default": 60, "constraints": { "min": 30, "max": 180 } }
    ]
  }
  ```
- NovaDesk 使用该 schema 验证模板字段，给出校验提示。

## 多 PC 同步建议

- 模板默认仅存本机；若需要多 PC 共用，可通过导入/导出手动同步。
- 可选：提供云端备份功能，但当前不在目标范围。

## 错误与校验

- 模板缺少必填字段 → 在执行前阻止提交。
- 字段类型不匹配 → 提示并回退。
- 文件路径不存在或读取失败 → 提示用户重新选择文件。
- 模板文件损坏 → 尝试解析失败时提示用户删除或恢复备份。

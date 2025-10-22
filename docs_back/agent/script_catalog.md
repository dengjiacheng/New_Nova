# 内置脚本管理

Agent 内置一组脚本，由开发者预先打包在 APK 中。脚本与脚本参数 schema 在 Agent 注册时同步给 Server。

## 目录结构

```
app/src/main/java/com/nova/agent/scripts/
  ScriptRegistry.kt
  ScriptLogin.kt
  ScriptCheckOut.kt
  ...
resources/
  scripts/
    SCRIPT_LOGIN/schema.json
    SCRIPT_LOGIN/metadata.json
```

- `ScriptRegistry` 维护 `scriptId -> ScriptDescriptor` 映射：
  ```kotlin
  data class ScriptDescriptor(
      val id: String,
      val version: String,
      val handler: ScriptHandler,
      val parameterSchema: ParameterSchema
  )
  ```
- `ScriptHandler` 定义统一接口：
  ```kotlin
  interface ScriptHandler {
      suspend fun run(ctx: ExecutionContext, reporter: Reporter): ExecutionResult
  }
  ```

## 参数 Schema

每个脚本提供 JSON Schema 或自定义结构，示例：
```json
{
  "fields": [
    { "key": "username", "type": "string", "label": "用户名", "required": true },
    { "key": "password", "type": "password", "label": "密码", "required": true },
    { "key": "timeout", "type": "number", "label": "超时时间", "default": 60 }
  ],
  "constraints": {
    "timeout": { "min": 30, "max": 300 }
  }
}
```

Agent 启动时读取 schema，随 `REGISTER` 上报给 Server。Server 再透传给 PC 客户端展示字段信息。

## 脚本版本管理

- 每个脚本有独立版本号，更新脚本需同时更新 schema 与 handler。
- `scriptCatalog` 上报示例：
  ```json
  [
    {
      "id": "SCRIPT_LOGIN",
      "version": "1.2.0",
      "checksum": "sha256:...",
      "parameters": { ...schema... },
      "capabilities": { "requiresOpenCv": false }
    }
  ]
  ```
- Server 存储最近一次上报，用于兼容性检查：
  - 若 PC 请求执行时指定的 `scriptVersion` 与 Agent 不一致，Server 返回 `SCRIPT_VERSION_MISMATCH`。
  - 可在 Server 下发脚本更新通知（非本阶段目标）。

## 脚本实现约定

- 不直接操作网络资源（除非脚本定义需要），避免与 Server 调度冲突。
- 使用 `ExecutionContext` 提供的工具：
  - `ctx.uiautomator`：UiAutomator 封装；
  - `ctx.ime`：自研 IME（暂为空实现，留接口）；
  - `ctx.opencv`：OpenCV 工具（可为空实现）。
- 脚本需捕获异常并返回结构化错误：
  ```kotlin
  ExecutionResult(
      status = ExecutionStatus.FAILURE,
      summary = "登录失败",
      error = ExecutionError(code = "LOGIN_TIMEOUT", message = "等待验证码超时")
  )
  ```

## 脚本更新流程

1. 开发者更新脚本并重新打包 Agent APK（签名发布包）。
2. 拥有权限的管理员通过 NovaDesk Admin Tools 上传 APK（`POST /api/admin/agent-packages`），填写版本信息与发布说明。
3. Server 完成校验后生成最新版本记录，并通过 `system.notice` 推送“Agent 新版本可用”通知；PC 端可调用 `GET /api/agent-packages/latest` 拉取元数据。
4. NovaDesk 在设备上线流程中比较本地 Agent 版本与最新版本，不一致时提示管理员执行 `adb install`；支持在 Admin Tools 内直接下载最新 APK。
5. 若需要强制升级，可在 Server 激活新版本后限制旧版本执行（见 `docs/server/websocket.md`、`docs/operations/config_and_deploy.md` 中约束策略）。

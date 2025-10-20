# Nova 项目协作入口指南

将本指南发给任何新加入或即将在独立会话中开展工作的成员，他们即可按照步骤快速对齐目标、阅读文档、维护 To-Do 并保持文档一致性。

---

## 第 0 步：通用要求

1. 阅读 `docs/operations/coding_guidelines.md`，了解全局开发规范、To-Do 管理规则与“文档先于代码”原则。
2. 确认自己负责的组件（Server / Desk / Agent），并记录任务来源（需求号、Issue、分支等）。
3. 检查是否已有相关任务条目；若无，创建新的 To-Do（或项目任务），并标明关联文档章节。

---

## 第 1 步：阅读总览

无论负责哪一端，请先快速浏览以下文档，掌握系统全貌与核心协议：

- `docs/architecture/overview.md`
- `docs/architecture/message_protocol.md`
- `docs/flows/core_flows.md`

若对角色/权限或部署背景有疑问，可补充阅读：

- `docs/operations/rbac.md`
- `docs/operations/multi_pc_login.md`
- `docs/operations/config_and_deploy.md`
- `docs/operations/future_work.md`

---

## 第 2 步：按组件进入详纲

### 负责 NovaServer（云端）的成员

1. 阅读 `docs/server/overview.md` 了解模块划分。
2. 继而按顺序查看：
   - `docs/server/rest_api.md`
   - `docs/server/websocket.md`
   - `docs/server/data_models.md`
   - `docs/server/billing_audit.md`
   - `docs/server/background_tasks.md`
3. 建立/更新本组 To-Do：列出当前迭代要交付的接口、模型、任务；每个条目关联上述文档的小节。
4. 开发或调整功能前，若接口/模型需变更，先更新对应文档，再编写代码。

### 负责 NovaDesk（PC 客户端）的成员

1. 阅读 `docs/desktop/overview.md`，明确分层结构与启动流程。
2. 继续查看：
   - `docs/desktop/device_management.md`
   - `docs/desktop/script_templates.md`
   - `docs/desktop/ui_flows.md`
   - `docs/desktop/local_storage.md`
3. 在 To-Do 中拆分 UI、状态管理、ADB 封装、模板处理等任务，引用文档段落。
4. 若需调整流程（例如设备上线、附件上传），务必先改文档再写代码。

### 负责 NovaAgent（Android 运行器）的成员

1. 阅读 `docs/agent/overview.md`，了解模块组成。
2. 继续查看：
   - `docs/agent/lifecycle.md`
   - `docs/agent/command_handling.md`
   - `docs/agent/script_catalog.md`
   - `docs/agent/reporting.md`
3. 在 To-Do 中列出 Runner 生命周期、指令处理、脚本目录、日志回传等任务，引用文档章节。
4. 如需新增脚本或能力（IME/OpenCV），先拓展文档中相应章节，再进行编码。

---

## 第 3 步：执行与维护

1. **开发前**：确认文档描述与需求一致；若发现缺失或不准确，立刻补充/修正文档。
2. **开发中**：保持模块化、分层、低耦合实现，遵循规范中的测试与日志要求。
3. **开发后**：
   - 更新 To-Do 状态，附上提交记录与文档链接。
   - 若接口/流程变化，通知受影响团队，并注明文档已更新。
   - 视需要补充运行说明或注释，确保下一位同事能够连续接手。

---

## 常见问题

- **不知道改哪个文档？** 搜索关键字或查看 `docs/README.md` 的目录结构，找到对应主题再编辑。
- **多人并行冲突？** 使用同一文档前先沟通，确定变更范围；写完后合并，确认无冲突再提交。
- **是否可以跳过文档？** 不可。任何需求、接口、流程改动必须先更新文档后写代码。
- **新的规范或流程？** 在 `docs/operations/` 目录新增文档，并在 `onboarding.md` 中补充指引。

---

按照本指南执行，任何人在新会话中都能快速进入状态，保持文档与实现同步演进，确保团队协作无缝衔接。

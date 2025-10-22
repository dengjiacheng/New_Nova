# Zero‑Command Autopilot · VS Code + ChatGPT Pro（无需 API）

**你只需要在 Chat 面板里说人话（例如：“给订单列表加分页”）**，其余都自动完成：
- 模型在本地写 **DCP（自动 accepted）→ 代码 → 测试**；
- 守护进程自动 **建分支 / 提交 / 推送 / 开 PR**；
- 多任务并发、模块级 PR、矩阵 CI（Java/Python/JS/Android/Flutter）。
**不需要**任何控制 JSON 或“ready_code”信号。

---

## 快速开始

```bash
unzip codex_zerocommand_multistack_autopilot.zip -d auto-zero
cd auto-zero
git init && git add . && git commit -m "chore: init zero-command autopilot"
git branch -M main
gh repo create --source=. --public --push   # 或自行设置远端并 push
npm install
npm run codex:watch   # 启动守护（常驻）
```

VS Code：
1) 安装并登录 **OpenAI ChatGPT 官方扩展**；
2) 打开 `.codex/prompts/zero_system.md` 全文复制到 Chat 的第一条；
3) 然后直接说：

```
给订单列表加分页，默认20最大100；兼容旧客户端；补齐契约与回归
```

守护会检测到新 DCP 与代码改动，自动开 **DCP PR** 和 **模块级 Code PR**。

---

## 工作方式（对你透明）

- 模型会自动创建或更新：
  - `docs/dcp/DCP-<ID>.md`（包含 front‑matter，`status: accepted`），并在 `.codex/current_task` 记录 `<ID>`；
  - 随后直接修改代码与测试（按需要跨 Java/Python/JS/Android/Flutter）。
- 守护自动：
  - 发现**新 DCP** → 建 `docs/<ID>` 分支 → 提交/推送 → **DCP PR**（`type:doc-plan`）；
  - 发现**代码变更** → 依据模块路径拆分分支 `feat/<ID>/<module>` → 提交/推送 → **各模块 Code PR**；
  - 在 `.codex/ledger/<ID>.json` 记录 PR 信息，重复变更会继续 push 到同一 PR。

> 若没有 `.codex/current_task`，守护会自动把**最近创建的 DCP**作为当前任务（2 小时窗口）。

---

## 目录

- `autopilot-local/watch_auto.js`  → 无需控制文件的智能守护（推送/PR 全自动）
- `.codex/prompts/zero_system.md` → “零指令”系统引导：只说目标，其它自动完成
- `.github/workflows/ci-matrix.yml` + `.github/paths.yml` → 路径过滤的多栈矩阵 CI
- `scripts/*` → 文档门禁、代码地图、标签初始化
- `docs/` → DCP/ADR/权威文档目录（模型自动生成/更新）

---

## 适配大型与多端项目

- **模块识别**：守护会读取 `.codex/projects.yaml` 的模块配置；若缺省，会自动扫描以下特征自动发现：
  - Java：`pom.xml` / `build.gradle` / `gradlew`
  - Python：`pyproject.toml` / `requirements*.txt`
  - Web/Node：`package.json`
  - Android：`app/build.gradle` 或目录名含 `android`
  - Flutter：`pubspec.yaml`
- **模块级 PR**：每个模块独立分支与 PR，互不干扰。
- **并发安全**：任务锁 + 模块锁；主分支合入请启用保护分支/合并队列。

---

## 指令示例（你只需要说目标）

- 接手盘点：`接手这个项目：两周内建立权威文档、测试基线（≥75%），输出治理路线与KPI`
- 新功能：`给订单列表加分页，page/page_size，默认20最大100；补齐契约与回归`
- 修 Bug：`修复库存负数；保持行为不变；补回归用例`
- 重构：`DAO 提取为仓储模式，不改对外行为；给出基准与回滚方案`
- 升级：`Spring Boot 升到 3.x，评估破坏性变更并提供分阶段迁移策略`

> 备注：你也可以继续用 `/codex run|fix|refactor|test|onboard` 之类前缀，但**不是必须**。

祝使用顺利！

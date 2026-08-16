---
name: project-memory
description: 跨会话的 Claude Code 项目记忆。触发词：初始化项目记忆 / init、恢复项目上下文 / start、更新项目记忆 / 更新记忆 / update、生成交接摘要 / 收尾 / handoff。提供按需加载、按任务序列衰减（类 LSTM 遗忘门）的多档记忆，避免每次会话都全量读入、爆掉 context。
---

# Project Memory

跨会话的、存在仓库里的项目记忆。目标是：**新会话开头只加载最相关的少量记忆，旧而琐碎的记忆自动冷却、按需才展开**——而不是把 current-state / decisions / task-log / handoff 全部塞进 context。

灵感来自 LLM Wiki（先读索引、再按需展开页面）与分层记忆（Hot/Warm/Cold）。衰减轴是 **任务序列**，不是日历时间。

---

## 1. 核心模型

### 三档（按需加载粒度）
| 档位 | 含义 | start 时是否默认加载 |
|------|------|----------------------|
| **hot**  | recency ≥ 0.67，最近几个任务触及的记忆 | 由 `load` 决定 |
| **warm** | 0.20 ≤ recency < 0.67，较旧记忆 | 由 `load` 决定 |
| **cold** | recency < 0.20，久远记忆 | 仅 `load: always` 自动加载 |

### 任务序列衰减（类 LSTM 遗忘门）
每条记忆记录它最近一次被哪个**任务序号**触及（`last_task`）。`current_seq` 取 `task-log*.md` 里最大的 `seq`。

```
tasks_since = current_seq - entry.last_task
recency     = 0.5 ^ (tasks_since / HALF_LIFE)
```

- `HALF_LIFE` 默认 **10 个任务**（可在 `MEMORY.md` 顶部的 `Half-life (tasks):` 改；也可用环境变量 `MEMORY_HALF_LIFE` 覆盖）。
- 每经过一个任务步，记忆乘一次遗忘因子 `0.5^(1/HALF_LIFE)`——最近的 context 权重大，远的低。

### importance、recency 与 load 分工
- `importance`（1-5）决定保留优先级和索引排序；高重要性决策不得被自动删除。
- `recency` 只反映任务距离，所有未触及的记忆都会正常变冷。
- `load` 决定是否进入新会话：`always` 始终加载；`recent` 仅在 hot/warm 时加载；`on-demand` 只在问题相关时展开。
- 缺少 `load` 的旧记忆默认为 `recent`。

> 为什么用「任务数」而不是「天数」：一个半年没动、但之后只过了 3 个任务的决定依然高度相关；而密集迭代时，几十个任务前的琐事就该快速冷却。距离的含义是「中间过了多少个任务」，不是「过了多少天」。

---

## 2. 文件布局

```
CLAUDE.md                              # 软指引（可选，指向 docs/project-memory）
docs/project-memory/
├── MEMORY.md                          # 索引（自动生成，先读它）
├── current-state.md                   # 当前状态/焦点/阻塞/下一步
├── decisions.md                       # 每条决策独立带 last_task/importance/load
├── task-log.md                        # 最新 30 条任务（每条带 seq，newest first）
├── session-handoff.md                 # 下次会话交接摘要
└── archive/                           # cold：冷却后迁出的旧记忆
    ├── decisions-archive.md
    └── task-log-archive.md
```

### 记忆页 frontmatter（current-state / session-handoff / archive/*）
```yaml
---
last_task: 48      # 最近一次触及它的任务 seq（衰减轴，必填）
importance: 4      # 1-5（驱动保留与排序，必填）
load: recent       # always / recent / on-demand（默认 recent）
date: 2026-08-14   # 人类可读备注，不参与衰减（可选）
summary: 一句话摘要，进索引   # 必填
---
```

### 决策条目（decisions.md）
```markdown
## D12 — 选择任务序列衰减
last_task: 48
importance: 5
load: recent
summary: 衰减按任务数计算，而不是按日期。

决策正文与权衡。
```
每条 `## D…` 决策独立进入 `MEMORY.md`，不会再共享文件级 recency。

### 任务流水条目（task-log.md，newest first）
```markdown
## T48 — 把 D1 决策写入 decisions.md
seq: 48
date: 2026-08-14
Verified: 跑过 memory-index.sh，recency 计算正确。
```
`seq` 单调递增；`current_seq` = 所有 `task-log*.md` 里最大的 `seq`。

---

## 3. 命令

### `/project-memory init`
在仓库里创建 `docs/project-memory/` 骨架 + `MEMORY.md` 空索引。若已存在则跳过。

### `/project-memory start`（新会话开头）
1. **只读 `MEMORY.md` 索引**（几行表格，极省 token）。
2. 加载 `Load` 列为 **`always`** 或 **`recent:auto`** 的页/条目。
3. `recent:on-demand` 与 `on-demand` 不默认读取；仅当用户问题明显相关时按索引展开。
4. 汇总当前状态，给出下一步。

### `/project-memory update`（有实质进展后）
1. 读 git diff / commit / 当前文件，判断改了什么。
2. 在 `task-log.md` 顶部插入新条目，`seq = current_seq + 1`。
3. 更新相关页或决策条目的 `last_task = 新 seq`；新决策必须填写 `importance`、`load` 与 `summary`。
4. 运行 `task-log-retention.sh docs/project-memory`，只保留最新 30 条活跃任务，旧条目迁入归档。
5. 运行 `memory-index.sh docs/project-memory` 重建 `MEMORY.md`。
6. 高 importance 决策允许变冷但不得自动删除；低重要性旧信息可迁入 archive，并保持按需加载。
7. 没跑验证命令就写 `Verified: not run`，不许假装成功。

### `/project-memory handoff`（收尾）
1. 执行一次 `update`。
2. 把 `session-handoff.md` 写成 < 300 字的下次会话交接（当前焦点、已完成、下一步、阻塞）。
3. 执行 task-log 保留并重建 `MEMORY.md`（含 `Current task seq`）。

---

## 4. 质量约束
- 记忆只存**操作型状态**（焦点/阻塞/下一步/决策/权衡），不存流水账。
- 优先保留用户手写内容；LLM 只补充结构化元数据（frontmatter、seq、summary）。
- 脏工作树里区分「已有改动」与「本次会话改动」。
- 索引 `MEMORY.md` 由 `memory-index.sh` 生成，**不要手改**；改了也会被下次 rebuild 覆盖。
- 向后兼容：没有 frontmatter 的旧文件按 `tasks_since = 0` 处理（recency 1.0，安全不降级）。
- archive task-log 永远按需加载，不能因为其中某条较新而整页进入上下文。

## 5. 配置
- `Half-life (tasks):` 写在 `MEMORY.md` 顶部（默认 10）。改大=记忆更持久，改小=衰减更激进。
- 临时覆盖：`MEMORY_HALF_LIFE=14 ./project-memory/memory-index.sh docs/project-memory`。
- 活跃任务默认上限 30；临时覆盖：`MEMORY_TASK_LOG_LIMIT=50 ./project-memory/task-log-retention.sh docs/project-memory`。

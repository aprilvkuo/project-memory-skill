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
| **hot**  | recency ≥ 0.67，最近几个任务触及的记忆 | 是（读全文） |
| **warm** | 0.20 ≤ recency < 0.67，较旧但重要 | 是（读全文） |
| **cold** | recency < 0.20，琐碎且久远的任务 | 否（仅在相关时按 MEMORY.md 索引展开） |

### 任务序列衰减（类 LSTM 遗忘门）
每条记忆记录它最近一次被哪个**任务序号**触及（`last_task`）。`current_seq` 取 `task-log*.md` 里最大的 `seq`。

```
tasks_since = current_seq - entry.last_task
recency     = max( floor[importance], 0.5 ^ (tasks_since / HALF_LIFE) )
```

- `HALF_LIFE` 默认 **10 个任务**（可在 `MEMORY.md` 顶部的 `Half-life (tasks):` 改；也可用环境变量 `MEMORY_HALF_LIFE` 覆盖）。
- 每经过一个任务步，记忆乘一次遗忘因子 `0.5^(1/HALF_LIFE)`——最近的 context 权重大，远的低。

### 重要性保底（关键决策永不被洗掉）
`floor[importance] = {5:0.50, 4:0.25, 3:0.10, 2:0.05, 1:0.00}`。
一条 imp5 的架构决策即使隔了 40 个任务，recency 也保底 0.50，永远留在 warm、永不被归档删除。低重要性（imp1）的旧琐事则衰减到接近 0，退入 cold。

> 为什么用「任务数」而不是「天数」：一个半年没动、但之后只过了 3 个任务的决定依然高度相关；而密集迭代时，几十个任务前的琐事就该快速冷却。距离的含义是「中间过了多少个任务」，不是「过了多少天」。

---

## 2. 文件布局

```
CLAUDE.md                              # 软指引（可选，指向 docs/project-memory）
docs/project-memory/
├── MEMORY.md                          # 索引（自动生成，先读它）
├── current-state.md                   # 当前状态/焦点/阻塞/下一步
├── decisions.md                       # 决策与权衡（带 importance + last_task）
├── task-log.md                        # 任务流水（每条带 seq，newest first）
├── session-handoff.md                 # 下次会话交接摘要
└── archive/                           # cold：冷却后迁出的旧记忆
    ├── decisions-archive.md
    └── task-log-archive.md
```

### 记忆页 frontmatter（current-state / decisions / session-handoff / archive/*）
```yaml
---
last_task: 48      # 最近一次触及它的任务 seq（衰减轴，必填）
importance: 4      # 1-5（驱动保底与排序，必填）
date: 2026-08-14   # 人类可读备注，不参与衰减（可选）
summary: 一句话摘要，进索引   # 必填
---
```

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
2. 加载 **hot + warm** 档全文（包括恰好落在 warm 的 archive 条目）。
3. **cold 档不读**；仅当用户问题明显相关（如「早期为什么选 X」）才按索引展开对应 archive 文件。
4. 汇总当前状态，给出下一步。

### `/project-memory update`（有实质进展后）
1. 读 git diff / commit / 当前文件，判断改了什么。
2. 在 `task-log.md` 顶部插入新条目，`seq = current_seq + 1`。
3. 更新相关记忆页 frontmatter：`last_task = 新 seq`；若产生了重要决策，补一条并设 `importance`；若内容仍重要，保留或上调 importance。
4. 运行 `memory-index.sh docs/project-memory` 重建 `MEMORY.md`。
5. **冷却→归档**：若某条记忆 recency 低于 cold 阈值且 importance ≤ 2，把条目迁到 `archive/`（原文件不再赘述，避免脏上下文）。imp ≥ 3 的不会被归档。
6. 没跑验证命令就写 `Verified: not run`，不许假装成功。

### `/project-memory handoff`（收尾）
1. 执行一次 `update`。
2. 把 `session-handoff.md` 写成 < 300 字的下次会话交接（当前焦点、已完成、下一步、阻塞）。
3. 重建 `MEMORY.md`（含 `Current task seq`）。

---

## 4. 质量约束
- 记忆只存**操作型状态**（焦点/阻塞/下一步/决策/权衡），不存流水账。
- 优先保留用户手写内容；LLM 只补充结构化元数据（frontmatter、seq、summary）。
- 脏工作树里区分「已有改动」与「本次会话改动」。
- 索引 `MEMORY.md` 由 `memory-index.sh` 生成，**不要手改**；改了也会被下次 rebuild 覆盖。
- 向后兼容：没有 frontmatter 的旧文件按 `tasks_since = 0` 处理（recency 1.0，安全不降级）。

## 5. 配置
- `Half-life (tasks):` 写在 `MEMORY.md` 顶部（默认 10）。改大=记忆更持久，改小=衰减更激进。
- 临时覆盖：`MEMORY_HALF_LIFE=14 ./project-memory/memory-index.sh docs/project-memory`。

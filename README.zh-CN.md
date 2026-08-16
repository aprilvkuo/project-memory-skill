# claude-project-memory（中文说明）

一个 [Claude Code](https://docs.claude.com/en/docs/claude-code) 技能，为你的项目提供
**跨会话的持久记忆**：**按需加载**，并带**任务序列衰减**（类 LSTM 遗忘门），让陈旧、琐碎的
上下文自动冷却，而不是每次会话都撑爆 context。

它与 Claude memory、`/init` 互补：记忆存在仓库里，跟踪当前进度与决策，并在会话间交接。

## 为什么要"按需加载 + 衰减"？

长期项目的记忆文件（`current-state` / `decisions` / `task-log` / handoff）会一直
膨胀，直到撑爆上下文窗口。本技能解决这个问题：

- **先读索引。** 每个会话开头只读取 `MEMORY.md`；只展开标记为 `always` 或
  `recent:auto` 的条目，其余按需读取。
- **按任务序列衰减，不是按天数。** 一个半年没动、但之后只过了 3 个任务的决定，依然高度相关。
  衰减的单位是"这条记忆距上次被触及中间过了多少个任务"，不是"过了多少天"。
- **重要性与加载解耦。** importance 决定保留与排序，`load` 决定是否自动进入上下文。
- **活跃历史有硬边界。** `task-log.md` 只保留最新 30 条，更早记录迁入按需归档。

## 安装

```bash
git clone https://github.com/aprilvkuo/claude-project-memory.git
cd claude-project-memory
./install.sh
```

安装到 `~/.claude/skills/project-memory`（如已存在会先备份）。用 `./uninstall.sh`
卸载（只删技能本身，不动仓库里的记忆文件）。

## 使用

| 命令 | 作用 |
|------|------|
| `/project-memory init`   | 创建 `docs/project-memory/` 骨架 + 空 `MEMORY.md`。 |
| `/project-memory start`  | 新会话：读 `MEMORY.md`，展开 `always` 与 `recent:auto`。 |
| `/project-memory update` | 有进展后：追加任务、保留 30 条活跃记录、重建索引。 |
| `/project-memory handoff`| 收尾：更新记忆 + 写 <300 字交接，重建索引。 |

## 衰减怎么算

```yaml
tasks_since = current_seq - entry.last_task      # current_seq = task-log*.md 里最大的 seq
recency     = 0.5 ^ (tasks_since / HALF_LIFE)
```

- `HALF_LIFE` 默认 **10 个任务**（在 `MEMORY.md` 顶部设 `Half-life (tasks):`，或用
  `MEMORY_HALF_LIFE=14` 临时覆盖）。
- 档位：**hot** recency ≥ 0.67，**warm** 0.20–0.67，**cold** < 0.20。

每条决策拥有独立元数据：

```markdown
## D12 — 项目记忆保存在仓库中
last_task: 48
importance: 5
load: recent
summary: 项目记忆保持人类可读并由 Git 跟踪。
```

`load` 可取 `always`、`recent`（默认）或 `on-demand`。陈旧的 importance-5
决策仍会保留并获得较高排序，但会正常变冷；除非设置 `always`，否则不再永久自动加载。

`task-log-retention.sh` 默认保留 30 条活跃记录，可用
`MEMORY_TASK_LOG_LIMIT=50` 覆盖。当前序号仍同时扫描活跃与归档日志；
`update` / `handoff` 会先归档再重建索引。

## 文件结构

```
docs/project-memory/
├── MEMORY.md                  # 自动生成的索引——先读它
├── current-state.md           # hot：状态 / 焦点 / 阻塞 / 下一步
├── decisions.md               # 按条目独立索引的决策与权衡
├── task-log.md                # 最新 30 条任务，每条带单调递增 seq
├── session-handoff.md         # hot：下次会话交接
└── archive/                   # cold：冷却后的旧记忆
    ├── decisions-archive.md
    └── task-log-archive.md
```

## 示例

见 [`examples/`](examples/) 中的条目元数据和生成索引。运行 `bash tests/run.sh`
执行无依赖回归测试，其中包括 500-task 生命周期测试和 30/470 活跃/归档边界检查。

## 许可证

MIT

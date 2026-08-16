# claude-project-memory（中文说明）

一个 [Claude Code](https://docs.claude.com/en/docs/claude-code) 技能，为你的项目提供
**跨会话的持久记忆**：**按需加载**，并带**任务序列衰减**（类 LSTM 遗忘门），让陈旧、琐碎的
上下文自动冷却，而不是每次会话都撑爆 context。

它与 Claude memory、`/init` 互补：记忆存在仓库里，跟踪当前进度与决策，并在会话间交接。

## 为什么要"按需加载 + 衰减"？

长期项目的记忆文件（`current-state` / `decisions` / `task-log` / handoff）会一直
膨胀，直到撑爆上下文窗口。本技能解决这个问题：

- **先读索引。** 每个会话开头只读取 `MEMORY.md` 这张小表格；hot + warm 页展开，cold 页折叠。
- **按任务序列衰减，不是按天数。** 一个半年没动、但之后只过了 3 个任务的决定，依然高度相关。
  衰减的单位是"这条记忆距上次被触及中间过了多少个任务"，不是"过了多少天"。
- **重要性保底。** 关键架构决策（importance 5）的 recency 永保 0.50，不会被归档洗掉。

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
| `/project-memory start`  | 新会话：读 `MEMORY.md`，展开 hot+warm，cold 按需。 |
| `/project-memory update` | 有进展后：追加任务流水、刷新 frontmatter、重建索引。 |
| `/project-memory handoff`| 收尾：更新记忆 + 写 <300 字交接，重建索引。 |

## 衰减怎么算

```yaml
tasks_since = current_seq - entry.last_task      # current_seq = task-log*.md 里最大的 seq
recency     = max( floor[importance], 0.5 ^ (tasks_since / HALF_LIFE) )
```

- `HALF_LIFE` 默认 **10 个任务**（在 `MEMORY.md` 顶部设 `Half-life (tasks):`，或用
  `MEMORY_HALF_LIFE=14` 临时覆盖）。
- `floor[importance] = {5:0.50, 4:0.25, 3:0.10, 2:0.05, 1:0.00}`。
- 档位：**hot** recency ≥ 0.67，**warm** 0.20–0.67，**cold** < 0.20。

`memory-index.sh` 会在每次 `update` / `handoff` 时自动重算索引。

## 文件结构

```
docs/project-memory/
├── MEMORY.md                  # 自动生成的索引——先读它
├── current-state.md           # hot：状态 / 焦点 / 阻塞 / 下一步
├── decisions.md               # warm：决策与权衡（含 importance、last_task）
├── task-log.md                # hot：任务流水，每条带单调递增 seq
├── session-handoff.md         # hot：下次会话交接
└── archive/                   # cold：冷却后的旧记忆
    ├── decisions-archive.md
    └── task-log-archive.md
```

## 示例

见 [`examples/`](examples/)——含由示例文件生成的 `MEMORY.md`，演示一条 importance-5
决策在隔了 38 个任务后仍保底 recency 0.50，而一条 importance-1 任务衰减到 0.05。

## 许可证

MIT

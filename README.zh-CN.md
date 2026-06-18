# Claude Project Memory

一个用于 Claude Code 的项目记忆 skill，让项目上下文在不同 session 之间持续保存。

Claude 的聊天记录是临时的，但项目记忆应该保存在项目里。这个工具会让 Claude Code 用一套固定流程创建、读取、更新和交接项目上下文，避免每次新开 session 都重新解释项目。

## 为什么需要它

Claude memory 记住“你是谁”。Claude Code 的 `/init` 描述“项目是什么”。Project Memory 记录“项目现在进行到哪”。

当项目跨很多 session 持续推进时，真正容易丢的不是项目简介，而是这些上下文：

- 最近做了什么
- 当前重点是什么
- 哪些决策已经定了
- 哪些问题还没解决
- 下一个 session 应该先做什么

Project Memory 就是为这些“项目交接信息”准备的。

## 和 Claude memory、`/init` 的区别

| 能力 | Claude memory | Claude Code `/init` | Project Memory |
| --- | --- | --- | --- |
| 记住长期个人偏好 | 强 | 弱 | 中 |
| 生成初始项目说明 | 弱 | 强 | 中 |
| 跟随项目仓库 | 不一定 | 通常是 | 是 |
| 记录当前进度 | 弱 | 弱 | 强 |
| 记录决策和取舍 | 弱 | 弱 | 强 |
| 生成下一 session 交接 | 弱 | 弱 | 强 |
| 配合 git 历史 | 弱 | 中 | 强 |
| 团队共享 | 弱 | 中 | 强 |

它不是替代 Claude memory 或 `/init`，而是补上它们不擅长的部分：

- Claude memory 适合保存你的长期偏好。
- `/init` 适合第一次扫描项目并生成项目说明。
- Project Memory 适合持续维护项目状态和 session 交接。

## 适合的使用场景

- 你经常为同一个项目新开 Claude Code session。
- 你隔几个小时或几天回来继续工作，希望快速恢复上下文。
- 项目里有一些已经决定过的技术/产品取舍，不希望 AI 反复推翻。
- 你经常切换模型、压缩上下文，或丢失旧聊天记录。
- 多个人或多个 AI agent 需要通过 git 共享项目状态。
- 你希望每次收尾时都有一个稳定的交接流程。

## 优势

- **项目本地化：** 记忆文件保存在项目仓库里，而不是只留在聊天记录里。
- **适合版本控制：** 进度、决策和交接摘要都可以被 git 跟踪。
- **偏向执行：** 记录当前状态和下一步，而不是冗长流水账。
- **支持中文触发：** 可以用“初始化项目记忆”“更新记忆”“生成交接摘要”“收尾”等中文表达。
- **低负担：** 开始时记住 `/project-memory start`，离开前记住 `/project-memory handoff` 就够了。

## 安装

```bash
git clone https://github.com/aprilvkuo/claude-project-memory.git
cd claude-project-memory
./install.sh
```

安装脚本会把 skill 复制到：

```text
~/.claude/skills/project-memory
```

如果本机已经安装过旧版本，脚本会先创建一个带时间戳的备份，再安装新版本。

## 使用

在 Claude Code 中运行：

```text
/project-memory init
```

这会在当前项目里初始化记忆文件：

```text
CLAUDE.md
docs/project-memory/current-state.md
docs/project-memory/decisions.md
docs/project-memory/task-log.md
docs/project-memory/session-handoff.md
```

新 session 开始时运行：

```text
/project-memory start
```

它会读取项目记忆，恢复当前状态、重点任务、遗留问题和建议下一步。

完成一段有意义的工作后运行：

```text
/project-memory update
```

它会根据当前对话、git diff、最近提交和文件状态更新长期记忆。

准备结束 session、切换模型或压缩上下文前运行：

```text
/project-memory handoff
```

`handoff` 会顺带执行必要的 `update`，然后生成给下一个 session 的简短交接摘要。所以如果你只想记一个收尾命令，记住 `handoff` 就够了。

## 命令区别

| 命令 | 用途 |
| --- | --- |
| `/project-memory init` | 初始化项目记忆文件结构。 |
| `/project-memory start` | 读取已有记忆，恢复项目上下文。 |
| `/project-memory update` | 根据当前工作更新长期项目记忆。 |
| `/project-memory handoff` | 更新记忆，并生成下一 session 的交接摘要。 |

## 会记录什么

Project Memory 只记录稳定、有用的项目状态：

- 当前项目目标
- 当前工作重点
- 最近有意义的变更
- 重要决策和取舍
- 未解决问题
- 下一 session 的最佳下一步

它不应该记录私有推理过程、完整聊天记录或噪声历史。

## 推荐工作流

第一次进入项目：

```text
/project-memory init
```

每次新 session 开始：

```text
/project-memory start
```

每次准备离开：

```text
/project-memory handoff
```

如果中途做了比较大的修改，也可以手动运行：

```text
/project-memory update
```

## 卸载

```bash
./uninstall.sh
```

这只会删除：

```text
~/.claude/skills/project-memory
```

不会删除任何项目里的记忆文件。

## License

MIT

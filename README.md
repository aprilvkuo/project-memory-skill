# Claude Project Memory

A Claude Code skill for durable project memory across sessions.

[中文说明](README.zh-CN.md)

Claude conversations are temporary. Project memory should live with the project. This skill gives Claude Code a small, repeatable workflow for creating, restoring, updating, and handing off project context without pasting the same instructions into every new session.

## Why This Exists

Claude memory remembers the user. Claude Code `/init` describes the project. Project Memory tracks where the project is right now.

This skill is useful when a project is active over many sessions and the important context is not just "what is this repository?" but "what did we just decide, what changed recently, what is still blocked, and what should the next session do first?"

## How It Compares

| Capability | Claude memory | Claude Code `/init` | Project Memory |
| --- | --- | --- | --- |
| Remembers long-term user preferences | Strong | Weak | Medium |
| Creates initial project guidance | Weak | Strong | Medium |
| Lives in the project repository | Not always | Usually | Yes |
| Tracks current progress | Weak | Weak | Strong |
| Records decisions and tradeoffs | Weak | Weak | Strong |
| Creates next-session handoffs | Weak | Weak | Strong |
| Works well with git history | Weak | Medium | Strong |
| Can be shared with a team | Weak | Medium | Strong |

Project Memory does not replace Claude memory or `/init`. It complements them:

- Use Claude memory for durable personal preferences.
- Use `/init` to bootstrap project-level instructions.
- Use Project Memory to keep the project state current across sessions.

## Best Use Cases

- You frequently start new Claude Code sessions for the same project.
- You come back to work after hours or days and want a fast context restore.
- The project has decisions that Claude should not repeatedly revisit.
- You switch models, compact context, or lose conversation history.
- Multiple people or agents need to share project status through git.
- You want a reliable end-of-session handoff ritual.

## Advantages

- **Project-local:** Memory files live in the repository, not only in a chat transcript.
- **Git-friendly:** Progress, decisions, and handoffs can be reviewed and versioned.
- **Operational:** It stores the current state and next action, not a long journal.
- **Bilingual triggers:** It understands English commands and common Chinese requests.
- **Low ceremony:** Remember `/project-memory start` when beginning and `/project-memory handoff` when leaving.

## Install

```bash
git clone https://github.com/aprilvkuo/claude-project-memory.git
cd claude-project-memory
./install.sh
```

The installer copies the skill to:

```text
~/.claude/skills/project-memory
```

If an older copy exists, the installer creates a timestamped backup before replacing it.

## Usage

In Claude Code, run:

```text
/project-memory init
```

This initializes project-local memory files:

```text
CLAUDE.md
docs/project-memory/current-state.md
docs/project-memory/decisions.md
docs/project-memory/task-log.md
docs/project-memory/session-handoff.md
```

At the beginning of a new session:

```text
/project-memory start
```

After meaningful work:

```text
/project-memory update
```

Before closing a session, switching models, or compacting context:

```text
/project-memory handoff
```

`handoff` also performs the useful parts of `update`, so it is the easiest command to remember at the end of a session.

## Commands

| Command | Purpose |
| --- | --- |
| `/project-memory init` | Create the project memory file structure. |
| `/project-memory start` | Read existing memory and summarize the current state. |
| `/project-memory update` | Update durable memory from the conversation, git diff, recent commits, and current file state. |
| `/project-memory handoff` | Update memory and write a concise next-session handoff. |

## What Gets Stored

Project memory is intentionally small and operational:

- current project state
- active focus
- recent meaningful changes
- important decisions and tradeoffs
- open issues
- next action for the next session

It should not store private chain-of-thought, long chat transcripts, or noisy history.

## Uninstall

```bash
./uninstall.sh
```

This removes:

```text
~/.claude/skills/project-memory
```

It does not remove memory files from your projects.

## License

MIT

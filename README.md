# Claude Project Memory

A Claude Code skill for durable project memory across sessions.

Claude conversations are temporary. Project memory should live with the project. This skill gives Claude Code a small, repeatable workflow for creating, restoring, updating, and handing off project context without pasting the same instructions into every new session.

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

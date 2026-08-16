# Codex and Hermes Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make one project-memory skill package installable and usable in Claude Code, Codex, and Nous Research Hermes Agent.

**Architecture:** Keep `project-memory/` as the single portable Agent Skills bundle. Extend the shell installer and uninstaller to operate on the three official user skill roots, while allowing test-safe environment overrides. Keep all memory/index behavior shared and make instructions resolve helper scripts from the loaded skill directory instead of the repository checkout.

**Tech Stack:** Portable `SKILL.md`, Bash, Markdown, Codex `agents/openai.yaml`.

## Global Constraints

- Do not duplicate the skill implementation per agent.
- Default install roots are `~/.claude/skills`, `~/.agents/skills`, and `~/.hermes/skills`.
- Preserve existing targets by timestamped backup before installation.
- Uninstallation removes only installed skill directories, never project memory or backups.
- Keep the existing memory regression suite passing.

---

### Task 1: Three-platform installer contract

**Files:**
- Create: `tests/test-installers.sh`
- Modify: `tests/run.sh`
- Modify: `install.sh`
- Modify: `uninstall.sh`

**Interfaces:**
- Consumes: `CLAUDE_SKILLS_DIR`, `CODEX_SKILLS_DIR`, and `HERMES_SKILLS_DIR` overrides.
- Produces: identical `project-memory` bundles in each configured skill root and removes them on uninstall.

- [ ] Write a test that points all three roots at temporary directories, seeds an existing file in every target, runs `install.sh`, verifies one backup and byte-identical installed payload per platform, runs `uninstall.sh`, and verifies only active targets were removed.
- [ ] Run `bash tests/test-installers.sh`; expect failure because Codex and Hermes targets are absent.
- [ ] Refactor installation into a loop over three named targets, preparing backups and copying the same source bundle.
- [ ] Refactor uninstallation into the same target loop without deleting backups.
- [ ] Run `bash tests/test-installers.sh && bash tests/run.sh`; expect PASS.

### Task 2: Portable skill instructions

**Files:**
- Modify: `project-memory/SKILL.md`
- Modify: `project-memory/agents/openai.yaml`
- Test: `tests/test-skill-portability.sh`
- Modify: `tests/run.sh`

**Interfaces:**
- Consumes: the loaded skill file path exposed by each agent runtime.
- Produces: provider-neutral invocation and deterministic helper-script resolution.

- [ ] Write a static contract test that rejects Claude-only metadata, requires all three agent names and invocation forms, requires `SKILL_DIR` resolution guidance, and validates the Codex default prompt contains `$project-memory`.
- [ ] Run `bash tests/test-skill-portability.sh`; expect failure on Claude-only wording and stale Codex UI metadata.
- [ ] Rewrite the skill description and procedures for Claude Code, Codex, and Hermes; specify `/project-memory` for Claude/Hermes and `$project-memory` for Codex.
- [ ] Update helper commands to resolve `SKILL_DIR` from the loaded `SKILL.md` path before invoking `memory-index.sh` or `task-log-retention.sh`.
- [ ] Update `agents/openai.yaml` with provider-neutral UI copy and a `$project-memory` default prompt.
- [ ] Run the portability contract and full suite; expect PASS.

### Task 3: Distribution documentation and local verification

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`

**Interfaces:**
- Consumes: implemented installation paths and invocation syntax.
- Produces: accurate install, update, uninstall, and verification instructions for all three runtimes.

- [ ] Document the shared standard, three default install locations, agent-specific invocation syntax, environment overrides, and Hermes direct GitHub installation option.
- [ ] Run `bash tests/run.sh`, `bash -n install.sh uninstall.sh project-memory/*.sh tests/*.sh`, and `git diff --check`.
- [ ] Run `./install.sh`, compare the source bundle with all three local targets, and verify Hermes with `hermes skills list` when the CLI is installed.
- [ ] Request code review, resolve Critical/Important findings, merge to `main`, and push after final verification.

# Security Policy

## Scope

**grokdrive** is an unofficial Claude Code extension: a dispatcher CLI, a PreToolUse
gate hook, and a doctrine skill. It routes execution to the Grok Build CLI
headless with `--always-approve` — an auto-approved, autonomous shell over the
working directory. Treat dispatched specs as capable of **arbitrary local
execution**.

## What we care about

1. **`--always-approve` body** — every `grokdrive` dispatch can run shell, edit
   files, and call tools under the Grok Build CLI. Do not dispatch secrets or
   sensitive code without redaction. Prefer sandbox/worktree isolation when the
   working tree is high-stakes.
2. **Gate is not a sandbox** — the PreToolUse hook constrains Claude's four
   mutation tools (`Write` / `Edit` / `MultiEdit` / `NotebookEdit`) only. It does
   **not** stop Bash-based file writes, MCP writes, or writes by spawned
   sub-agents. Those are doctrine-governed, not hook-enforced.
3. **No credentials in the repo** — never commit `.env`, tokens, session dumps,
   or real secrets. State lives under `~/.claude/.grokdrive-state/` (local only).
4. **External body is a cloud service** — Grok runs remotely. Do not put
   credentials, private keys, or unreleased IP into specs without redaction.

## Reporting

Open a GitHub issue with the `security` label, or email the maintainers via the
org contact on GitHub. Do **not** attach real secrets; use synthetic fixtures.

## Supported versions

Best-effort on the latest `main` / latest release tag only. There is no paid SLA.

## Threat model (short)

| Asset | Risk | Mitigation |
|-|-|-|
| Working tree under `--always-approve` | Arbitrary local execution by Grok body | Spec hygiene; sandbox/worktree; review diffs before merge |
| Claude mutation tools while mode on | Advisor hand-edits work files | PreToolUse gate on four tools only |
| Bash / MCP / sub-agent writes | Bypass of mutation-tool gate | Skill doctrine; not hook-enforced |
| Specs / artifacts on disk | Secret re-surface in prompts | Redact before dispatch; keep state out of git |
| Install | Path confusion / settings.json surgery | Symlinks only into this repo; backup before first edit |

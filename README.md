# grokdrive

**Grok does the work. Claude keeps the judgment.**

Session-scoped "burn Grok credit" mode for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). When ON, Grok 4.5 (via the Grok Build CLI, headless) does all execution while the Claude session model (Opus / Fable) stays the advisor-orchestrator: it plans, routes, writes specs, reviews, and verifies — but never hand-edits work files. The package is a small Claude Code extension: a dispatcher CLI, a hard PreToolUse gate hook, and a doctrine skill.

## How it works

**Brain / body split.** Claude is the brain (judgment). Grok is the body (implementation). While the mode is active for a session, a PreToolUse hook (`grokdrive-gate.js`) blocks direct Claude `Write` / `Edit` / `MultiEdit` / `NotebookEdit` on project files. Execution is forced through:

```bash
grokdrive "<self-contained spec>"
```

which dispatches the spec to Grok. Effort auto-tiers (HIGH for complex specs, MEDIUM for standard). Each dispatch writes a raw artifact; `verify --gate "<cmd>"` produces a GREEN / RED verdict marker. Kill the mode with `grokdrive off` or `CLAUDE_GUARDS_OFF=1`.

## Requirements

| Need | Notes |
|-|-|
| Claude Code | Session host; loads the PreToolUse hook at session start |
| Grok Build CLI (`grok`) | On PATH; used for every dispatch |
| `node` | Runs the gate hook |
| `python3` | Settings JSON surgery + CLI helpers |
| `bash` | Installer and dispatcher |

## Install

```bash
git clone https://github.com/Rennlabs/grokdrive.git
cd grokdrive
./install.sh
```

This is also a Claude Code plugin: drop the repo into a plugin marketplace; `hooks/hooks.json` wires the gate via `${CLAUDE_PLUGIN_ROOT}`.

**Caveat:** the gate arms only in Claude Code sessions started *after* install (the hook set loads at session start). Start a fresh session, then run `grokdrive on`.

Preview without mutating your machine:

```bash
./install.sh --dry-run
```

## Usage

```bash
# Arm / disarm (session-scoped by default)
grokdrive on [--advisor opus|fable] [--effort auto|high|medium|low] [--global]
grokdrive off
grokdrive status

# Dispatch
grokdrive "<full self-contained spec>"     # bare form
grokdrive run -f spec.md                   # big spec via file
git diff | grokdrive "review+fix"          # stdin as context
grokdrive parallel "A" "B" "C"             # independent bodies

# External proof
grokdrive verify --gate "pytest -q" [--loop <mode>]

# Health
grokdrive doctor
```

## Routing doctrine

| Send to Grok (body) | Keep in Claude (brain) |
|-|-|
| Implementation from a frozen spec | Design, API shape, architecture, naming, UX |
| Refactors, mechanical migrations | Tasks where writing the spec *is* the work |
| Bug fixes with a known repro | Session-tool work (MCP, secrets, browser) |
| Test writing, coverage fills | Destructive / irreversible / release / push ops |
| CI fixes, dependency bumps | **Review of Grok's output (never delegated)** |
| Bulk exploration (raw reading ≫ answer) | |

Heuristic: *prompt reads as an assignment → Grok; writing it forces the decisions → keep it.*

## The prompt contract

Grok starts each dispatch with **zero** session context. Every spec must carry:

1. **Goal** — what done looks like
2. **Repo + key paths** — exact tree locations
3. **Constraints / non-goals** — what not to touch
4. **Exact proof command** — e.g. `pytest -q`, `npm test`
5. **Output shape** — files changed, command stdout, residual risks

Spec quality decides success.

## Verify

Grok's summary is advisory. Read the real diff, then run the external gate yourself:

```bash
grokdrive verify --gate "pytest -q"
grokdrive verify --gate "npm test" --loop autopilot
```

GREEN iff the gate exits 0. `--loop <mode>` also stamps that loop's verifier marker. On RED, dispatch a fix body with concrete failure notes and re-verify. Never close on a summary card alone.

## Configuration

| Variable | Default | Meaning |
|-|-|-|
| `GROKDRIVE_EFFORT` | `auto` | `auto` \| `high` \| `medium` \| `low` |
| `GROKDRIVE_MODEL` | empty | Empty = Grok default 4.5 |
| `GROKDRIVE_MAX_TURNS` | `60` | Max turns per dispatch |
| `GROKDRIVE_TIMEOUT` | `1200` | Dispatch timeout (seconds) |
| `GROKDRIVE_SANDBOX` | empty | Passed through to `grok` when set |
| `GROKDRIVE_TRIVIAL_LINES` | `20` | Allowlisted edit size (0 = no exceptions) |
| `GROKDRIVE_STATE_DIR` | `~/.claude/.grokdrive-state` | Mode state directory |
| `CLAUDE_GUARDS_OFF` | unset | Set to `1` to disable the gate |

## How the gate works

- **Per-session state** at `~/.claude/.grokdrive-state/<session_id>.json` (`all.json` for `--global`). No active state ⇒ no-op; concurrent unrelated sessions are never affected.
- **Always allowed** while active: trivial edits ≤ `GROKDRIVE_TRIVIAL_LINES` (default 20); paths under `~/.claude/**`, `~/.local/bin/**`, `/tmp/claude-*`.
- **Kill-switch:** `CLAUDE_GUARDS_OFF=1` or `grokdrive off`.
- **Fail-soft:** any hook error is a no-op (never wedges a tool call).
- Only the four mutation tools are gated; Read / Grep / Glob / Bash stay free so the advisor can inspect and invoke `grokdrive`.

## Uninstall

```bash
./install.sh --uninstall
```

Removes the three symlinks (only if they point into this repo) and strips the grokdrive PreToolUse entry from `~/.claude/settings.json`, leaving other hooks intact.

## License

MIT © 2026 Renn Labs

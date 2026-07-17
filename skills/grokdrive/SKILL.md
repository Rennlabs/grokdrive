---
name: grokdrive
description: >
  Burn-Grok-credit mode — route ALL execution and heavy sub-agent work to the
  Grok Build CLI's current default model (Grok 4.5 at time of writing; effort
  high/medium), keeping the Claude session model (Opus/Fable) as
  advisor-orchestrator only: it plans, routes, reviews, verifies, never uses
  the native edit tools on work files. A PreToolUse gate blocks direct Claude
  Write/Edit/MultiEdit/NotebookEdit while active (Bash remains a deliberate
  escape hatch). Use on /grokdrive, "grokdrive", "grok mode", "burn grok
  credit", "route execution to grok", "grok body", or when the user wants Grok
  doing the work and Claude just orchestrating.
---

# grokdrive — Grok body, Claude brain

Flip a session-scoped mode where **Grok does the work** (via the Grok Build
CLI's current default model — Grok 4.5 at time of writing) and the **Claude
session model (Opus or Fable) only orchestrates**. Built to spend Grok credit
while keeping Claude's judgment on plan / route / review / verify.

This is a **hard gate on Claude's four mutation tools + strong friction/
discipline — not a sandbox.**

**Status line — lead every reply while active:**

```
🔁 LOOP · grokdrive · advisor=<opus|fable> · <goal ≤8 words> · verifier: GREEN|RED|—
```

`verifier: —` until the first `grokdrive verify`; then `GREEN|RED`.

---

## Turn it on / off

```bash
grokdrive on                       # this session; effort auto (high|medium), advisor=opus
grokdrive on --advisor fable --effort auto
grokdrive on --global              # every session (use sparingly)
grokdrive status
grokdrive off                      # restore direct Claude execution
```

`on` arms a hard gate **on Claude's four mutation tools**: while active, the
`grokdrive-gate.js` PreToolUse hook **blocks direct Claude
Write/Edit/MultiEdit/NotebookEdit** on non-allowlisted project paths. Direct
Claude edits via those mutation tools are blocked; Bash writes remain a
deliberate escape hatch (see Limits). Kill-switch: `grokdrive off` or
`CLAUDE_GUARDS_OFF=1`.

**Allowed even while active** (so the mode stays usable): trivial edits ≤20 changed lines
(`GROKDRIVE_TRIVIAL_LINES`, set 0 for no exceptions), and edits under `~/.claude/**`,
`~/.local/bin/**`, `/tmp/claude-**` (advisor/config/scratch territory).

### Limits — what the gate does and doesn't stop

| | |
|-|-|
| **Stops** | Direct Claude `Write` / `Edit` / `MultiEdit` / `NotebookEdit` on non-allowlisted paths |
| **Does NOT stop** | Bash-based file writes, MCP writes, or writes by spawned sub-agents |

Those unstopped paths are governed by this skill's doctrine, not the hook. If
you need a harder boundary, run Grok in a sandbox/worktree and treat
`--always-approve` accordingly.

**Activation scope (important):** the gate is a **PreToolUse hook**, and Claude Code loads
its hook set at **session start**. So it enforces in every session that began *after* the
hook was installed — i.e. any normal working session: run `grokdrive on` and the gate bites
for the rest of it. It does **not** retroactively arm the one session where the hook was
first installed (its hook chain is already fixed); start a fresh session for enforcement
there. The gate is per-session: `grokdrive on` only arms the session it's run in (use
`--global` to arm all). If the hook ever seems not to fire, `grokdrive doctor` confirms it's
registered; a not-yet-reloaded session is the usual cause.

## Dispatch execution to Grok

```bash
grokdrive "<full self-contained spec>"          # one body; bare form
grokdrive run -f spec.md                         # big spec via file
git diff | grokdrive "review + fix per this diff"# stdin appended as context
grokdrive parallel "task A" "task B" "task C"     # independent chunks, collected
```

Effort **auto-tiers**: HIGH for large/complex specs (refactor, architecture, debug,
multi-file, security), MEDIUM for standard ones. Force it with `--effort high|medium|low`
or `GROKDRIVE_EFFORT`. Each dispatch writes a raw artifact under
`.omc/artifacts/grokdrive/` and prints its path — open it to check claims against raw output.

## Routing doctrine — body (Grok) vs brain (Claude)

Send to the **Grok body** (prompt reads like a work order):
- implementation from a frozen spec; refactors; mechanical migrations
- bug fixes with a known repro; test writing; coverage fills
- CI fixes, dependency bumps, scripts/tooling
- bulk exploration where raw reading ≫ the answer

Keep in the **Claude brain** (advisor-orchestrator):
- design, API design, architecture, naming, UX judgment
- tasks where writing the spec *is* the work (ambiguity = design)
- session-tool work (MCP, secrets, browser/computer-use); destructive/irreversible ops, releases, pushes
- **review of Grok's output — never delegated, never skipped**

Heuristic: *prompt reads as an assignment → Grok; writing it forces the decisions → keep it.*

## Sub-agents

While active, do **not** spawn Claude execution sub-agents (executor/designer/writer/
test-engineer) via the Agent/Task tool — route that work to `grokdrive` instead (Grok
runs its own sub-agents via `grok --agents`/`--best-of-n` inside the dispatch). The Agent
tool stays available for **Claude advisor sub-agents only** — planner, architect, critic,
code-reviewer, verifier — because those are the orchestrator's judgment, not execution.

## Prompt contract (every dispatch)

The Grok body starts with **zero** session context. Each spec must carry: the goal, exact
repo + key paths, constraints ("don't touch X"), non-goals, the **exact proof command**
(e.g. `pytest -q`), and the output shape ("report files changed + test output"). Spec
quality decides success.

## Verify — always, and yourself

Grok's summary is **advisory**. Read the full diff like a reviewer, then run the external
gate yourself:

```bash
grokdrive verify --gate "pytest -q"          # writes .omc/state/grokdrive-verifier.json
grokdrive verify --gate "npm test" --loop autopilot   # also stamps the active loop marker
```

GREEN iff the gate exits 0. On RED, dispatch fix bodies with concrete failure notes and
re-verify. After ~2 failed rounds, stop delegating and reason it out in the brain (or
`grokdrive off` and fix directly). Never close on a summary card alone.

## Doctor

```bash
grokdrive doctor    # grok on PATH, state writable, gate hook present + registered
```

## Env knobs

`GROKDRIVE_EFFORT` (auto|high|medium|low) · `GROKDRIVE_MODEL` (empty = Grok Build CLI
default; Grok 4.5 at time of writing) · `GROKDRIVE_MAX_TURNS` (60) ·
`GROKDRIVE_TIMEOUT` (1200s) · `GROKDRIVE_SANDBOX` · `GROKDRIVE_TRIVIAL_LINES` (20) ·
`CLAUDE_GUARDS_OFF=1` disables the gate.

## Doctrine

- **Grok executes, Claude orchestrates.** The session model plans, routes, reviews, verifies — it does not use the four mutation tools on work files while the mode is on (Bash remains an intentional escape hatch).
- **Route effort by difficulty** — don't burn HIGH on trivia; auto-tiering handles the common case.
- **Never trust a summary card** — verify against the raw diff + gate stdout.
- **One status line per reply** — mode, advisor, goal, verifier state at a glance.

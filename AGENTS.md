# Grokdrive project rules

## Product

Grokdrive is a **session-scoped brain/body split** for Claude Code:

- **Brain** — Claude session model (plan / route / review / verify)
- **Body** — Grok Build CLI via `grokdrive "<spec>"` (headless, `--always-approve`)

## Policy

- **Gate scope:** PreToolUse blocks only `Write` / `Edit` / `MultiEdit` /
  `NotebookEdit` on non-allowlisted paths. Not a sandbox.
- **Escape hatch:** Bash (and MCP / sub-agent) writes are doctrine-governed, not
  hook-enforced. See README "What the gate does and doesn't stop."
- **Fail-soft hook:** any gate error is a no-op; never wedge tool calls.
- **Kill-switch:** `grokdrive off` or `CLAUDE_GUARDS_OFF=1`.
- **Verify yourself:** Grok summaries are advisory; run `grokdrive verify --gate`.

## Agent non-goals

Coding agents **must not**:

1. Claim the gate is escape-proof, a hard wall, or a sandbox.
2. Spawn Claude *execution* sub-agents while mode is on — route those to `grokdrive`.
3. Close work on a Grok summary card without an external gate (tests/build/lint).
4. Dispatch secrets or sensitive trees without redaction / isolation.

## Dev

```bash
bash -n bin/grokdrive install.sh
node --check hooks/grokdrive-gate.js
./install.sh --dry-run
grokdrive doctor
```

# Changelog

## [0.2.0] - 2026-07-20

### Security

- `parallel` honors `GROKDRIVE_ALWAYS_APPROVE` refuse path
- Abort install on invalid settings.json (never wipe to `{}`)

### Added

- `explain`, `log`, `version` subcommands
- Status/doctor print **not-a-sandbox** boundary + session-restart honesty
- Append-only audit log; gate denials logged from the PreToolUse hook
- `GROKDRIVE_ALWAYS_APPROVE` (default 1; set 0 to refuse headless dispatches)
- Installer `--force` (backup foreign files)

### Changed

- `on` / `status` / `doctor` surface boundary and restart caveats in-product

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-19

Initial public release — session-scoped grokdrive mode (Grok executes, Claude orchestrates).

### Added

- Session-scoped grokdrive mode (Grok executes, Claude orchestrates)
- Dispatcher CLI (`on` / `off` / `status` / `run` / `parallel` / `verify` / `doctor`)
- PreToolUse gate hook (`grokdrive-gate.js`) blocking direct Claude Write/Edit while active
- Doctrine skill (`skills/grokdrive/SKILL.md`)
- Standalone installer (`install.sh`) + Claude Code plugin manifest
- `SECURITY.md`, `CONTRIBUTING.md`, `AGENTS.md`
- `.github/workflows/ci.yml` (bash `-n`, `node --check`, shellcheck severity=error)

### Notes

- Honest gate framing: a hard gate on Claude's four mutation tools + friction — not a sandbox.
  Bash / MCP / sub-agent writes are governed by doctrine, not the hook (see README, "What the
  gate does and doesn't stop").
- Model references use "the Grok Build CLI's current default model (Grok 4.5 at time of writing)".
- Unofficial — not affiliated with xAI.

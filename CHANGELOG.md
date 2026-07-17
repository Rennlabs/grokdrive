# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-07-16

### Changed

- Honest gate framing: hard gate on Claude's four mutation tools + friction —
  not a sandbox. Documented what the gate does and does not stop (Bash / MCP /
  sub-agent writes are doctrine-governed).
- Softened hardcoded model claim to "Grok Build CLI's current default model
  (Grok 4.5 at time of writing)".
- Unofficial / not affiliated with xAI + break-risk note in README.

### Fixed

- `install.sh` dry-run banner: real installs no longer print `[dry-run]`
  (`${DRY_RUN:+…}` treated any set value as true, including the default `0`).

### Added

- `SECURITY.md`, `CONTRIBUTING.md`, `AGENTS.md`
- `.github/workflows/ci.yml` (bash `-n`, `node --check`, shellcheck severity=error)
- `.omx/` and `.buildlog/` in `.gitignore`

## [0.1.0] - 2026-07-16

### Added

- Session-scoped grokdrive mode (Grok executes, Claude orchestrates)
- Dispatcher CLI (`on` / `off` / `status` / `run` / `parallel` / `verify` / `doctor`)
- PreToolUse gate hook (`grokdrive-gate.js`) blocking direct Claude Write/Edit while active
- Doctrine skill (`skills/grokdrive/SKILL.md`)
- Standalone installer (`install.sh`) + Claude Code plugin manifest

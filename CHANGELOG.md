# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-16

### Added

- Session-scoped grokdrive mode (Grok executes, Claude orchestrates)
- Dispatcher CLI (`on` / `off` / `status` / `run` / `parallel` / `verify` / `doctor`)
- PreToolUse gate hook (`grokdrive-gate.js`) blocking direct Claude Write/Edit while active
- Doctrine skill (`skills/grokdrive/SKILL.md`)
- Standalone installer (`install.sh`) + Claude Code plugin manifest

# Contributing

Thanks for interest in **grokdrive** (unofficial Claude Code + Grok Build companion).

## Dev setup

```bash
git clone https://github.com/Rennlabs/grokdrive.git
cd grokdrive
bash -n bin/grokdrive install.sh
node --check hooks/grokdrive-gate.js
./install.sh --dry-run   # optional: preview install without mutating
```

## Guidelines

1. Keep the PreToolUse gate **scoped to the four mutation tools only**. Bash is a
   deliberate escape hatch; document any change that tightens or loosens it.
2. Truth-in-advertising: do not claim the gate is a sandbox or escape-proof wall.
3. Small PRs; run `bash -n` and `node --check` before pushing.
4. No secrets in fixtures or docs (synthetic only).

## PR checklist

- [ ] `bash -n bin/grokdrive install.sh` and `node --check hooks/grokdrive-gate.js` pass
- [ ] No secrets or private absolute paths in the diff
- [ ] README/docs updated if gate scope or install behavior changes
- [ ] CHANGELOG note under Unreleased (or next version)

## Code of conduct

Be respectful. This is a small best-effort project.

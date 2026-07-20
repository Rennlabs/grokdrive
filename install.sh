#!/usr/bin/env bash
# install.sh — standalone installer for grokdrive
#
# Installs CLI + gate hook + skill via symlinks into ~/.local/bin and ~/.claude,
# and registers the PreToolUse gate in ~/.claude/settings.json.
#
# Usage:
#   ./install.sh              # install (idempotent)
#   ./install.sh --dry-run    # print actions, mutate nothing
#   ./install.sh --uninstall  # reverse install
#   ./install.sh --force      # backup foreign files then replace
#   ./install.sh -h|--help
set -euo pipefail

# Resolve REPO_ROOT as the directory containing this script (handle symlinks).
_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$_SOURCE" ]]; do
  _DIR="$(cd -P "$(dirname "$_SOURCE")" && pwd)"
  _SOURCE="$(readlink "$_SOURCE")"
  [[ "$_SOURCE" != /* ]] && _SOURCE="$_DIR/$_SOURCE"
done
REPO_ROOT="$(cd -P "$(dirname "$_SOURCE")" && pwd)"
unset _SOURCE _DIR

HOME_DIR="${HOME:?HOME not set}"
BIN_SRC="$REPO_ROOT/bin/grokdrive"
HOOK_SRC="$REPO_ROOT/hooks/grokdrive-gate.js"
SKILL_SRC="$REPO_ROOT/skills/grokdrive"

BIN_DST="$HOME_DIR/.local/bin/grokdrive"
HOOK_DST="$HOME_DIR/.claude/hooks/grokdrive-gate.js"
SKILL_DST="$HOME_DIR/.claude/skills/grokdrive"
SETTINGS="$HOME_DIR/.claude/settings.json"
SETTINGS_BAK="$HOME_DIR/.claude/settings.json.grokdrive.bak"
HOOK_CMD="node $HOME_DIR/.claude/hooks/grokdrive-gate.js"
HOOK_MATCHER="Write|Edit|MultiEdit|NotebookEdit"

DRY_RUN=0
UNINSTALL=0
FORCE=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Install grokdrive (CLI, PreToolUse gate hook, doctrine skill) for Claude Code.

Options:
  --dry-run     Print every action; mutate nothing
  --uninstall   Remove symlinks and the PreToolUse hook registration
  --force       Backup foreign files, then replace with managed symlinks
  -h, --help    Show this help

Install is idempotent. Symlinks point into this repo; settings.json is edited
with python3 (backed up to settings.json.grokdrive.bak before the first edit).

After install: START A FRESH Claude Code session (hooks load at session start).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

log() { printf '%s\n' "$*"; }
run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] $*"
  else
    eval "$@"
  fi
}

# Resolve a path to an absolute real path when possible (for symlink compare).
_realpath() {
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$1" 2>/dev/null || echo "$1"
  else
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null || echo "$1"
  fi
}

# Returns 0 if path is a symlink whose ultimate target is under REPO_ROOT.
_points_into_repo() {
  local path="$1"
  [[ -L "$path" ]] || return 1
  local target
  target="$(_realpath "$path")"
  local root
  root="$(_realpath "$REPO_ROOT")"
  [[ "$target" == "$root"/* ]] || [[ "$target" == "$root" ]]
}

# Safe symlink: skip if already correct; warn+skip if exists pointing elsewhere.
safe_symlink() {
  local src="$1" dst="$2"
  local dst_dir
  dst_dir="$(dirname "$dst")"

  if [[ ! -e "$src" ]]; then
    echo "install.sh: ERROR: source missing: $src" >&2
    exit 1
  fi

  if [[ -L "$dst" ]]; then
    if _points_into_repo "$dst"; then
      local cur
      cur="$(_realpath "$dst")"
      local want
      want="$(_realpath "$src")"
      if [[ "$cur" == "$want" ]]; then
        log "  already linked: $dst -> $src"
        return 0
      fi
      # Points into repo but not this exact source — still our territory; replace.
      log "  re-link: $dst -> $src"
      run "rm -f $(printf %q "$dst")"
      run "ln -s $(printf %q "$src") $(printf %q "$dst")"
      return 0
    fi
    if [[ "${FORCE:-0}" -eq 1 ]]; then
      local bak="${dst}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
      log "  backup: $dst -> $bak"
      run "mv $(printf %q "$dst") $(printf %q "$bak")"
      log "  ln -s $src $dst"
      run "ln -s $(printf %q "$src") $(printf %q "$dst")"
      return 0
    fi
    echo "  WARN: $dst exists and points elsewhere; skip (use --force)" >&2
    return 0
  fi

  if [[ -e "$dst" ]]; then
    if [[ "${FORCE:-0}" -eq 1 ]]; then
      local bak="${dst}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
      log "  backup: $dst -> $bak"
      run "mv $(printf %q "$dst") $(printf %q "$bak")"
      log "  ln -s $src $dst"
      run "mkdir -p $(printf %q "$dst_dir")"
      run "ln -s $(printf %q "$src") $(printf %q "$dst")"
      return 0
    fi
    echo "  WARN: $dst exists and is not a symlink; skip (use --force)" >&2
    return 0
  fi

  log "  mkdir -p $dst_dir"
  run "mkdir -p $(printf %q "$dst_dir")"
  log "  ln -s $src $dst"
  run "ln -s $(printf %q "$src") $(printf %q "$dst")"
}

# Remove symlink only if it points into this repo.
safe_unlink() {
  local dst="$1"
  if [[ ! -e "$dst" && ! -L "$dst" ]]; then
    log "  not present: $dst"
    return 0
  fi
  if [[ -L "$dst" ]] && _points_into_repo "$dst"; then
    log "  rm $dst"
    run "rm -f $(printf %q "$dst")"
    return 0
  fi
  if [[ -L "$dst" ]]; then
    echo "  WARN: $dst points outside this repo; leave in place" >&2
    return 0
  fi
  echo "  WARN: $dst is not a grokdrive symlink; leave in place" >&2
}

register_hook() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] register PreToolUse hook in $SETTINGS (matcher=$HOOK_MATCHER)"
    log "[dry-run]   command: $HOOK_CMD"
    log "[dry-run]   backup: $SETTINGS_BAK (if settings exist and no bak yet)"
    return 0
  fi

  python3 - "$SETTINGS" "$SETTINGS_BAK" "$HOOK_CMD" "$HOOK_MATCHER" <<'PY'
import json, os, sys, shutil

settings_path, bak_path, hook_cmd, matcher = sys.argv[1:5]

# Create empty settings if missing
if not os.path.isfile(settings_path):
    os.makedirs(os.path.dirname(settings_path), exist_ok=True)
    with open(settings_path, "w", encoding="utf-8") as f:
        json.dump({}, f, indent=2)
        f.write("\n")
    print(f"  created {settings_path}")

with open(settings_path, "r", encoding="utf-8") as f:
    raw = f.read()
try:
    data = json.loads(raw) if raw.strip() else {}
except json.JSONDecodeError as e:
    print(f"ERROR: {settings_path} is not valid JSON ({e}). Fix or restore from backup; refusing to overwrite.", file=sys.stderr)
    sys.exit(1)

if not isinstance(data, dict):
    print(f"ERROR: {settings_path} root must be a JSON object; refusing to overwrite.", file=sys.stderr)
    sys.exit(1)

hooks = data.setdefault("hooks", {})
if not isinstance(hooks, dict):
    hooks = {}
    data["hooks"] = hooks

ptu = hooks.setdefault("PreToolUse", [])
if not isinstance(ptu, list):
    ptu = []
    hooks["PreToolUse"] = ptu

# Idempotent: skip if any existing PreToolUse command mentions grokdrive-gate.js
def commands_in(entry):
    cmds = []
    if not isinstance(entry, dict):
        return cmds
    for h in entry.get("hooks") or []:
        if isinstance(h, dict) and "command" in h:
            cmds.append(str(h["command"]))
    if "command" in entry:
        cmds.append(str(entry["command"]))
    return cmds

for entry in ptu:
    for c in commands_in(entry):
        if "grokdrive-gate.js" in c:
            print("  PreToolUse hook already registered; skip")
            sys.exit(0)

# Backup before first edit
if not os.path.isfile(bak_path):
    shutil.copy2(settings_path, bak_path)
    print(f"  backup -> {bak_path}")
else:
    # Still snapshot current before this edit when bak already exists from prior install
    shutil.copy2(settings_path, bak_path)
    print(f"  backup refreshed -> {bak_path}")

entry = {
    "matcher": matcher,
    "hooks": [
        {"type": "command", "command": hook_cmd}
    ],
}
ptu.append(entry)
data["hooks"] = hooks

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"  registered PreToolUse hook in {settings_path}")
PY
}

unregister_hook() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] strip grokdrive PreToolUse hook from $SETTINGS"
    return 0
  fi

  if [[ ! -f "$SETTINGS" ]]; then
    log "  settings.json not present; nothing to strip"
    return 0
  fi

  python3 - "$SETTINGS" <<'PY'
import json, os, sys

settings_path = sys.argv[1]
with open(settings_path, "r", encoding="utf-8") as f:
    try:
        data = json.load(f)
    except json.JSONDecodeError:
        print("  settings.json not valid JSON; leave untouched")
        sys.exit(0)

if not isinstance(data, dict):
    print("  settings.json not an object; leave untouched")
    sys.exit(0)

hooks = data.get("hooks")
if not isinstance(hooks, dict):
    print("  no hooks block; nothing to strip")
    sys.exit(0)

ptu = hooks.get("PreToolUse")
if not isinstance(ptu, list):
    print("  no PreToolUse list; nothing to strip")
    sys.exit(0)

def is_grokdrive(entry):
    if not isinstance(entry, dict):
        return False
    for h in entry.get("hooks") or []:
        if isinstance(h, dict) and "grokdrive-gate.js" in str(h.get("command", "")):
            return True
    if "grokdrive-gate.js" in str(entry.get("command", "")):
        return True
    return False

kept = [e for e in ptu if not is_grokdrive(e)]
removed = len(ptu) - len(kept)
if removed == 0:
    print("  no grokdrive PreToolUse entry found")
    sys.exit(0)

hooks["PreToolUse"] = kept
data["hooks"] = hooks
with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"  stripped {removed} grokdrive PreToolUse entr{'y' if removed == 1 else 'ies'} from {settings_path}")
PY
}

# ---- main ----
if [[ "$UNINSTALL" -eq 1 ]]; then
  log "grokdrive uninstall (repo: $REPO_ROOT)$( [[ $DRY_RUN -eq 1 ]] && printf ' [dry-run]' )"
  log "Removing symlinks (only if they point into this repo):"
  safe_unlink "$BIN_DST"
  safe_unlink "$HOOK_DST"
  safe_unlink "$SKILL_DST"
  log "Stripping PreToolUse registration:"
  unregister_hook
  log "Done."
  exit 0
fi

log "grokdrive install (repo: $REPO_ROOT)$( [[ $DRY_RUN -eq 1 ]] && printf ' [dry-run]' )"

# Preflight: warn if grok CLI missing
if ! command -v grok >/dev/null 2>&1; then
  echo "WARNING: 'grok' not found on PATH. The Grok Build CLI is required for dispatch." >&2
  echo "         Install it, then re-run doctor: grokdrive doctor" >&2
fi

log "Symlinks:"
safe_symlink "$BIN_SRC" "$BIN_DST"
safe_symlink "$HOOK_SRC" "$HOOK_DST"
safe_symlink "$SKILL_SRC" "$SKILL_DST"

log "settings.json:"
register_hook

if [[ "$DRY_RUN" -eq 1 ]]; then
  log ""
  log "[dry-run] complete — no files were modified."
  exit 0
fi

log ""
log "Installed:"
log "  CLI:   $BIN_DST"
log "  hook:  $HOOK_DST"
log "  skill: $SKILL_DST"
log "  settings: $SETTINGS"
log ""
log "Caveat: the gate arms only in Claude Code sessions started AFTER install"
log "(the hook set loads at session start). Start a fresh session, then run:"
log "  grokdrive on"
log ""
log "Done."

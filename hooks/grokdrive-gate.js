#!/usr/bin/env node
'use strict';
/**
 * PreToolUse hook: grokdrive gate.
 *
 * When "grokdrive" burn-mode is ACTIVE for the current session, Claude must stay
 * the advisor-orchestrator (plan / route / review / verify) and route all real
 * EXECUTION to Grok 4.5 via `grokdrive "<spec>"`. This hook enforces that by
 * BLOCKING direct Claude file mutation (Write / Edit / MultiEdit / NotebookEdit)
 * while the mode is on.
 *
 * Activation is per-session: `grokdrive on` writes ~/.claude/.grokdrive-state/<sid>.json
 * with active:true; the hook matches the PreToolUse payload's session_id against it
 * (a global all.json applies to every session). No active state => no-op, so ordinary
 * sessions are never affected.
 *
 * Allowances (never blocked, so the mode stays usable + can't self-lock):
 *   - advisor/config/scratch territory: ~/.claude/**, ~/.local/bin/**, /tmp/claude-**
 *   - trivial edits: <= GROKDRIVE_TRIVIAL_LINES changed lines (default 20; set 0 for a
 *     no-exceptions hard gate).
 *
 * Scope: only the 4 mutation tools are gated. Read/Grep/Glob/Bash stay free (advisor
 * inspection + running grokdrive/git). Bash-based file writes are an intentional escape
 * hatch governed by the skill doctrine, not this hook.
 *
 * Convention: deny via stdout { hookSpecificOutput.permissionDecision:'deny' } + exit 0
 * (matches destructive-bash-guard). Fail-soft: any error => exit 0. Kill-switch:
 * CLAUDE_GUARDS_OFF=1.
 */

const fs = require('fs');
const path = require('path');

const HOME = process.env.HOME || process.env.USERPROFILE || '/tmp';
const STATE_DIR = process.env.GROKDRIVE_STATE_DIR || path.join(HOME, '.claude', '.grokdrive-state');
const TRIVIAL_LINES = (() => {
  const n = parseInt(process.env.GROKDRIVE_TRIVIAL_LINES || '20', 10);
  return Number.isFinite(n) ? n : 20;
})();
const MUTATORS = /^(Write|Edit|MultiEdit|NotebookEdit)$/;

function disabled() {
  const v = String(process.env.CLAUDE_GUARDS_OFF || '').trim().toLowerCase();
  return v === '1' || v === 'true' || v === 'yes';
}

function readState(sid) {
  const cands = [];
  if (sid) cands.push(path.join(STATE_DIR, sid + '.json'));
  cands.push(path.join(STATE_DIR, 'all.json'));
  for (const f of cands) {
    try {
      const s = JSON.parse(fs.readFileSync(f, 'utf8'));
      if (s && s.active === true) return s;
    } catch (_) { /* missing/invalid => skip */ }
  }
  return null;
}

function changedLines(tool, ti) {
  try {
    if (tool === 'Write') return String(ti.content || '').split('\n').length;
    if (tool === 'NotebookEdit') return String(ti.new_source || '').split('\n').length;
    if (tool === 'Edit') {
      const a = String(ti.new_string || '').split('\n').length;
      const b = String(ti.old_string || '').split('\n').length;
      return Math.max(a, b);
    }
    if (tool === 'MultiEdit') {
      const edits = Array.isArray(ti.edits) ? ti.edits : [];
      return edits.reduce((s, e) => s + String((e && e.new_string) || '').split('\n').length, 0);
    }
  } catch (_) { /* fall through */ }
  return Infinity; // unknown shape => treat as non-trivial (safer to gate)
}

function allowedPath(fp) {
  if (!fp) return false;
  // Directory prefixes: match the dir itself or anything strictly under it (boundary-safe,
  // so ~/.claude-backup or ~/.local/bin-ish are NOT wrongly allowed).
  const dirs = [
    path.join(HOME, '.claude'),
    path.join(HOME, '.local', 'bin'),
    STATE_DIR,
  ];
  for (const d of dirs) {
    if (fp === d || fp.startsWith(d + path.sep)) return true;
  }
  // Scratchpad: harness temp roots like /tmp/claude-<uid>/... (deliberate partial prefix).
  if (fp.startsWith('/tmp/claude-')) return true;
  return false;
}

function audit(row) {
  try {
    const line = JSON.stringify(Object.assign({ ts: new Date().toISOString() }, row)) + '\n';
    fs.appendFileSync(path.join(STATE_DIR, 'audit.jsonl'), line);
  } catch (_) { /* never fail closed on audit */ }
}

function deny(reason, meta) {
  audit(Object.assign({ type: 'deny', reason: String(reason).slice(0, 200) }, meta || {}));
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason: reason,
    },
  }));
  process.exit(0);
}

function denyMsg(tool, fp, advisor, effort) {
  return [
    '[grokdrive gate — burn-Grok-credit mode is ACTIVE]',
    '',
    `Direct Claude ${tool} on ${fp || '<file>'} is blocked. You are the ADVISOR-ORCHESTRATOR`,
    `(${advisor}); route this execution to Grok 4.5 instead:`,
    '',
    '  grokdrive "<full self-contained spec: goal, files, constraints, proof command,',
    '             expected output>"',
    '',
    `Grok effort auto-tiers (high for complex, medium for standard; current: ${effort}).`,
    'After Grok returns, read the real diff and run  grokdrive verify --gate "<test/build>".',
    'Keep planning, design, review, and verification in Claude — just not the edits.',
    '',
    `Trivial edits (<= ${TRIVIAL_LINES} lines) pass automatically. Exit the mode with`,
    '`grokdrive off`, or disable the gate for this session with CLAUDE_GUARDS_OFF=1.',
  ].join('\n');
}

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { if (raw.length < 1024 * 1024) raw += c; });
process.stdin.on('end', () => {
  try {
    if (disabled()) process.exit(0);
    let data;
    try { data = JSON.parse(raw || '{}'); } catch (_) { process.exit(0); }

    const tool = String(data.tool_name || '');
    if (!MUTATORS.test(tool)) process.exit(0);

    const sid = data.session_id || process.env.CLAUDE_CODE_SESSION_ID || '';
    const state = readState(sid);
    if (!state) process.exit(0); // mode not active for this session

    const ti = data.tool_input || {};
    const fp = String(ti.file_path || ti.notebook_path || '');
    if (allowedPath(fp)) process.exit(0);

    if (TRIVIAL_LINES > 0 && changedLines(tool, ti) <= TRIVIAL_LINES) process.exit(0);

    deny(denyMsg(tool, fp, state.advisor || 'opus', state.effort || 'auto'), {
      tool: tool,
      path: fp,
      session: sid,
      advisor: state.advisor || 'opus',
    });
  } catch (_) {
    process.exit(0); // never wedge a tool call on a hook bug
  }
});

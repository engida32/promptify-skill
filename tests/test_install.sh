#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok: %s\n' "$*"; }

export HOME="$TMP/home"
export OPENCODE_CONFIG_DIR="$TMP/opencode"
export CLAUDE_CONFIG_DIR="$TMP/claude"
export AGENTS_CONFIG_DIR="$TMP/agents"
export PROMPTIFY_STATE_DIR="$TMP/state"
mkdir -p "$HOME" "$OPENCODE_CONFIG_DIR/commands"

printf 'pre-existing user file\n' > "$OPENCODE_CONFIG_DIR/commands/promptify.md"

bash "$ROOT/install.sh" --all >/dev/null
[ -f "$OPENCODE_CONFIG_DIR/commands/promptify.md" ] || fail "OpenCode command missing"
[ -f "$CLAUDE_CONFIG_DIR/skills/promptify/SKILL.md" ] || fail "Claude skill missing"
[ -f "$AGENTS_CONFIG_DIR/skills/promptify/SKILL.md" ] || fail "Agents skill missing"
[ -f "$PROMPTIFY_STATE_DIR/installed.tsv" ] || fail "manifest missing"
[ "$(wc -l < "$PROMPTIFY_STATE_DIR/installed.tsv")" -eq 3 ] || fail "manifest should have 3 entries"
pass "installs all three targets"

bash "$ROOT/install.sh" --all >/dev/null
[ "$(wc -l < "$PROMPTIFY_STATE_DIR/installed.tsv")" -eq 3 ] || fail "manifest gained duplicates"
pass "reinstall is idempotent"

printf '\nmodified by user\n' >> "$CLAUDE_CONFIG_DIR/skills/promptify/SKILL.md"
bash "$ROOT/install.sh" --uninstall >/dev/null
[ -f "$CLAUDE_CONFIG_DIR/skills/promptify/SKILL.md" ] || fail "modified file was deleted"
[ ! -f "$OPENCODE_CONFIG_DIR/commands/promptify.md" ] || fail "unmodified OpenCode file was kept"
[ ! -f "$AGENTS_CONFIG_DIR/skills/promptify/SKILL.md" ] || fail "unmodified Agents file was kept"
[ ! -f "$PROMPTIFY_STATE_DIR/installed.tsv" ] || fail "manifest was not removed"
pass "uninstall removes only matching files"

backup_count="$(find "$OPENCODE_CONFIG_DIR/commands" -name 'promptify.md.bak.*' | wc -l)"
[ "$backup_count" -ge 1 ] || fail "pre-existing file was not backed up"
grep -q 'pre-existing user file' "$OPENCODE_CONFIG_DIR/commands/"promptify.md.bak.* || fail "backup lost original content"
pass "pre-existing file is backed up"

export PROMPTIFY_STATE_DIR="$TMP/state-empty"
mkdir -p "$PROMPTIFY_STATE_DIR"
printf 'do not delete\n' > "$TMP/keep.md"
bash "$ROOT/install.sh" --uninstall >/dev/null 2>&1 || true
[ -f "$TMP/keep.md" ] || fail "no-manifest uninstall deleted an unrelated file"
pass "no-manifest uninstall leaves files alone"

export PROMPTIFY_STATE_DIR="$TMP/state-agents"
rm -rf "$TMP/opencode" "$TMP/claude" "$TMP/agents"
bash "$ROOT/install.sh" --agents >/dev/null
[ -f "$AGENTS_CONFIG_DIR/skills/promptify/SKILL.md" ] || fail "--agents did not install the skill"
[ ! -f "$OPENCODE_CONFIG_DIR/commands/promptify.md" ] || fail "--agents installed OpenCode too"
pass "--agents is scoped"

printf 'all installer tests passed\n'

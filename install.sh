#!/usr/bin/env bash
#
# Promptify Skill installer
# Installs the /promptify command for OpenCode and the promptify skill for
# Claude Code. Safe to re-run: unchanged files are skipped and modified files
# are backed up before being replaced.
#
set -euo pipefail

REPO_OWNER="opencode-dev"
REPO_NAME="promptify-skill"
REPO_BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"

if [ -t 1 ]; then
    GREEN=$'\033[0;32m'
    BLUE=$'\033[0;34m'
    YELLOW=$'\033[0;33m'
    RED=$'\033[0;31m'
    NC=$'\033[0m'
else
    GREEN=""
    BLUE=""
    YELLOW=""
    RED=""
    NC=""
fi

info() { printf '%s\n' "${BLUE}$*${NC}"; }
ok()   { printf '%s\n' "${GREEN}[ok] $*${NC}"; }
warn() { printf '%s\n' "${YELLOW}[warn] $*${NC}"; }
die()  { printf '%s\n' "${RED}[error] $*${NC}" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: install.sh [options]

Options:
  --all         Install for every supported agent, even if not detected.
  --opencode    Install only the OpenCode command.
  --claude      Install only the Claude Code skill.
  --uninstall   Remove files previously installed by this script.
  -h, --help    Show this help.

Environment:
  OPENCODE_CONFIG_DIR   Override ~/.config/opencode
  CLAUDE_CONFIG_DIR     Override ~/.claude
EOF
}

TARGET_OPENCODE=0
TARGET_CLAUDE=0
UNINSTALL=0
EXPLICIT_TARGET=0

while [ $# -gt 0 ]; do
    case "$1" in
        --all)       TARGET_OPENCODE=1; TARGET_CLAUDE=1; EXPLICIT_TARGET=1 ;;
        --opencode)  TARGET_OPENCODE=1; EXPLICIT_TARGET=1 ;;
        --claude)    TARGET_CLAUDE=1; EXPLICIT_TARGET=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h|--help)   usage; exit 0 ;;
        *)           die "unknown option: $1 (try --help)" ;;
    esac
    shift
done

# Resolve the directory this script lives in. When the script is piped from
# curl, BASH_SOURCE is empty, so assets are downloaded instead.
SRC_ROOT=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

TEMP_FILES=()
cleanup() {
    if [ ${#TEMP_FILES[@]} -gt 0 ]; then
        rm -f -- "${TEMP_FILES[@]}"
    fi
}
trap cleanup EXIT

resolve_asset() {
    rel_path="$1"
    if [ -n "$SRC_ROOT" ] && [ -f "$SRC_ROOT/$rel_path" ]; then
        printf '%s\n' "$SRC_ROOT/$rel_path"
        return 0
    fi
    command -v curl >/dev/null 2>&1 \
        || die "curl is required when installing from a pipe"
    tmp_file="$(mktemp "${TMPDIR:-/tmp}/promptify.XXXXXX")"
    TEMP_FILES+=("$tmp_file")
    curl -fsSL "$RAW_BASE/$rel_path" -o "$tmp_file" \
        || die "could not download $rel_path"
    printf '%s\n' "$tmp_file"
}

install_file() {
    src_file="$1"
    dest_file="$2"
    mkdir -p "$(dirname "$dest_file")"

    if [ -f "$dest_file" ] && cmp -s "$src_file" "$dest_file"; then
        ok "already current: $dest_file"
        return 0
    fi

    if [ -f "$dest_file" ]; then
        backup_file="$dest_file.bak.$(date +%Y%m%d%H%M%S)"
        cp -- "$dest_file" "$backup_file"
        warn "backed up existing file to $backup_file"
    fi

    cp -- "$src_file" "$dest_file"
    chmod 644 "$dest_file"
    ok "installed: $dest_file"
}

OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# Legacy OpenCode releases read command files from "commands"; current ones
# read "command". Mirror into the legacy directory only when it already exists.
OPENCODE_COMMAND_DIRS=("$OPENCODE_CONFIG_DIR/command")
if [ -d "$OPENCODE_CONFIG_DIR/commands" ]; then
    OPENCODE_COMMAND_DIRS+=("$OPENCODE_CONFIG_DIR/commands")
fi

if [ "$UNINSTALL" -eq 1 ]; then
    info "Removing Promptify..."
    for dir in "${OPENCODE_COMMAND_DIRS[@]}"; do
        if [ -f "$dir/promptify.md" ]; then
            rm -f -- "$dir/promptify.md"
            ok "removed: $dir/promptify.md"
        fi
    done
    if [ -f "$CLAUDE_CONFIG_DIR/skills/promptify/SKILL.md" ]; then
        rm -f -- "$CLAUDE_CONFIG_DIR/skills/promptify/SKILL.md"
        rmdir "$CLAUDE_CONFIG_DIR/skills/promptify" 2>/dev/null || true
        ok "removed: $CLAUDE_CONFIG_DIR/skills/promptify/SKILL.md"
    fi
    ok "Uninstall complete. Backup files (.bak.*) were left in place."
    exit 0
fi

if [ "$EXPLICIT_TARGET" -eq 0 ]; then
    TARGET_OPENCODE=1
    if [ -d "$CLAUDE_CONFIG_DIR" ] || [ -d "$HOME/.config/claude" ]; then
        TARGET_CLAUDE=1
    fi
fi

info "Initializing Promptify Skill installer..."

if [ "$TARGET_OPENCODE" -eq 1 ]; then
    info "Checking OpenCode directories..."
    command_src="$(resolve_asset ".opencode/commands/promptify.md")"
    for dir in "${OPENCODE_COMMAND_DIRS[@]}"; do
        install_file "$command_src" "$dir/promptify.md"
    done
else
    warn "Skipped OpenCode (not selected)."
fi

if [ "$TARGET_CLAUDE" -eq 1 ]; then
    info "Mapping Claude Code skill layer..."
    skill_src="$(resolve_asset "skills/promptify/SKILL.md")"
    install_file "$skill_src" "$CLAUDE_CONFIG_DIR/skills/promptify/SKILL.md"
else
    warn "Skipped Claude Code (not detected). Use --claude to force."
fi

ok "Promptify installation complete. Restart your session and run /promptify."

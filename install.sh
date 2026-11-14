#!/usr/bin/env bash
#
# Promptify Skill installer
# Installs the /promptify command for OpenCode and the promptify skill for
# Claude Code and shared ~/.agents skill scanners. Safe to re-run: unchanged
# files are skipped, modified files are backed up, and uninstall removes only
# files recorded in the install manifest with a matching hash.
#
set -euo pipefail

REPO_OWNER="engida32"
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

assert_runtime_path() {
    # shellcheck disable=SC2016 # match literal placeholders, not the expanded path
    case "$1" in
        *'$HOME'*|*'${HOME}'*)
            die "path contains an unexpanded home marker: $1"
            ;;
    esac
}

usage() {
    cat <<'EOF'
Usage: install.sh [options]

Options:
  --all         Install for every supported agent, even if not detected.
  --opencode    Install only the OpenCode command.
  --claude      Install only the Claude Code skill.
  --agents      Install only the shared ~/.agents skill.
  --uninstall   Remove files recorded in the install manifest.
  -h, --help    Show this help.

Environment:
  OPENCODE_CONFIG_DIR   Override ~/.config/opencode
  CLAUDE_CONFIG_DIR     Override ~/.claude
  AGENTS_CONFIG_DIR     Override ~/.agents
  PROMPTIFY_STATE_DIR   Override ~/.local/state/promptify
EOF
}

TARGET_OPENCODE=0
TARGET_CLAUDE=0
TARGET_AGENTS=0
UNINSTALL=0
EXPLICIT_TARGET=0

while [ $# -gt 0 ]; do
    case "$1" in
        --all)       TARGET_OPENCODE=1; TARGET_CLAUDE=1; TARGET_AGENTS=1; EXPLICIT_TARGET=1 ;;
        --opencode)  TARGET_OPENCODE=1; EXPLICIT_TARGET=1 ;;
        --claude)    TARGET_CLAUDE=1; EXPLICIT_TARGET=1 ;;
        --agents)    TARGET_AGENTS=1; EXPLICIT_TARGET=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h|--help)   usage; exit 0 ;;
        *)           die "unknown option: $1 (try --help)" ;;
    esac
    shift
done

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

file_hash() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        die "sha256sum or shasum is required"
    fi
}

OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
AGENTS_CONFIG_DIR="${AGENTS_CONFIG_DIR:-$HOME/.agents}"
PROMPTIFY_STATE_DIR="${PROMPTIFY_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/promptify}"
MANIFEST="$PROMPTIFY_STATE_DIR/installed.tsv"

assert_runtime_path "$OPENCODE_CONFIG_DIR"
assert_runtime_path "$CLAUDE_CONFIG_DIR"
assert_runtime_path "$AGENTS_CONFIG_DIR"
assert_runtime_path "$PROMPTIFY_STATE_DIR"

OPENCODE_COMMAND_DIR="$OPENCODE_CONFIG_DIR/commands"
OPENCODE_LEGACY_DIR="$OPENCODE_CONFIG_DIR/command"

prepare_opencode_layout() {
    mkdir -p "$OPENCODE_CONFIG_DIR"

    if [ -L "$OPENCODE_COMMAND_DIR" ] && [ ! -e "$OPENCODE_COMMAND_DIR" ]; then
        link_target="$(readlink "$OPENCODE_COMMAND_DIR" 2>/dev/null || true)"
        if [ "$link_target" = "$OPENCODE_LEGACY_DIR" ]; then
            warn "removing broken legacy link: $OPENCODE_COMMAND_DIR"
            rm -f -- "$OPENCODE_COMMAND_DIR"
        else
            die "broken symlink at $OPENCODE_COMMAND_DIR; fix it and retry"
        fi
    fi

    if [ -d "$OPENCODE_LEGACY_DIR" ] && [ ! -e "$OPENCODE_COMMAND_DIR" ]; then
        legacy_abs="$(cd "$OPENCODE_LEGACY_DIR" && pwd)"
        ln -s "$legacy_abs" "$OPENCODE_COMMAND_DIR" \
            || die "could not link $OPENCODE_COMMAND_DIR to $OPENCODE_LEGACY_DIR"
        ok "linked $OPENCODE_COMMAND_DIR -> $legacy_abs"
    fi

    mkdir -p "$OPENCODE_COMMAND_DIR"
}

opencode_command_dirs() {
    printf '%s\n' "$OPENCODE_COMMAND_DIR"
    if [ -d "$OPENCODE_LEGACY_DIR" ] \
        && [ ! "$OPENCODE_LEGACY_DIR" -ef "$OPENCODE_COMMAND_DIR" ]; then
        printf '%s\n' "$OPENCODE_LEGACY_DIR"
    fi
}

record_install() {
    dest_file="$1"
    hash="$2"
    mkdir -p "$PROMPTIFY_STATE_DIR"
    tmp_manifest="$(mktemp "$PROMPTIFY_STATE_DIR/manifest.XXXXXX")"
    if [ -f "$MANIFEST" ]; then
        awk -F '\t' -v d="$dest_file" '$1 != d' "$MANIFEST" > "$tmp_manifest"
    fi
    printf '%s\t%s\n' "$dest_file" "$hash" >> "$tmp_manifest"
    mv -f -- "$tmp_manifest" "$MANIFEST"
}

install_file() {
    src_file="$1"
    dest_file="$2"
    mkdir -p "$(dirname "$dest_file")"

    if [ -f "$dest_file" ] && cmp -s "$src_file" "$dest_file"; then
        ok "already current: $dest_file"
        record_install "$dest_file" "$(file_hash "$dest_file")"
        return 0
    fi

    if [ -f "$dest_file" ]; then
        backup_file="$dest_file.bak.$(date +%Y%m%d%H%M%S).$$"
        cp -- "$dest_file" "$backup_file"
        warn "backed up existing file to $backup_file"
    fi

    tmp_file="$(mktemp "${dest_file}.tmp.XXXXXX")"
    cp -- "$src_file" "$tmp_file"
    chmod 644 "$tmp_file"
    mv -f -- "$tmp_file" "$dest_file"
    record_install "$dest_file" "$(file_hash "$dest_file")"
    ok "installed: $dest_file"
}

validate_skill() {
    skill_file="$1"
    [ -f "$skill_file" ] || die "skill file is missing: $skill_file"
    head -n 1 "$skill_file" | grep -qx -- '---' \
        || die "skill is missing YAML frontmatter: $skill_file"
    grep -q '^name: promptify$' "$skill_file" \
        || die "skill frontmatter is missing 'name: promptify': $skill_file"
    if grep -q '^disable-model-invocation: true$' "$skill_file"; then
        warn "skill still opts out of model invocation; Hermes may not auto-select it"
    fi
}

uninstall() {
    info "Removing Promptify..."
    if [ ! -f "$MANIFEST" ]; then
        warn "no install manifest at $MANIFEST; nothing removed"
        return 0
    fi

    removed=0
    kept=0
    while IFS=$'\t' read -r dest_file expected_hash; do
        [ -n "$dest_file" ] || continue
        if [ ! -e "$dest_file" ]; then
            continue
        fi
        current_hash="$(file_hash "$dest_file")"
        if [ "$current_hash" = "$expected_hash" ]; then
            rm -f -- "$dest_file"
            ok "removed: $dest_file"
            removed=$((removed + 1))
            parent="$(dirname "$dest_file")"
            case "$parent" in
                */skills/promptify) rmdir "$parent" 2>/dev/null || true ;;
            esac
        else
            warn "modified since install; left in place: $dest_file"
            kept=$((kept + 1))
        fi
    done < "$MANIFEST"

    rm -f -- "$MANIFEST"
    rmdir "$PROMPTIFY_STATE_DIR" 2>/dev/null || true
    ok "Uninstall complete: $removed removed, $kept kept. Backups (.bak.*) were left in place."
}

OPENCODE_COMMAND_DIRS=()
while IFS= read -r dir; do
    OPENCODE_COMMAND_DIRS+=("$dir")
done < <(opencode_command_dirs)

if [ "$UNINSTALL" -eq 1 ]; then
    uninstall
    exit 0
fi

if [ "$EXPLICIT_TARGET" -eq 0 ]; then
    TARGET_OPENCODE=1
    if [ -d "$CLAUDE_CONFIG_DIR" ] || [ -d "$HOME/.config/claude" ]; then
        TARGET_CLAUDE=1
    fi
    if [ -d "$AGENTS_CONFIG_DIR/skills" ] || [ -d "$AGENTS_CONFIG_DIR" ]; then
        TARGET_AGENTS=1
    fi
fi

info "Initializing Promptify Skill installer..."

if [ "$TARGET_OPENCODE" -eq 1 ]; then
    info "Checking OpenCode directories..."
    prepare_opencode_layout
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
    validate_skill "$skill_src"
    install_file "$skill_src" "$CLAUDE_CONFIG_DIR/skills/promptify/SKILL.md"
else
    warn "Skipped Claude Code (not detected). Use --claude to force."
fi

if [ "$TARGET_AGENTS" -eq 1 ]; then
    info "Mapping shared agents skill layer..."
    skill_src="$(resolve_asset "skills/promptify/SKILL.md")"
    validate_skill "$skill_src"
    install_file "$skill_src" "$AGENTS_CONFIG_DIR/skills/promptify/SKILL.md"
else
    warn "Skipped shared agents skill (not detected). Use --agents to force."
fi

ok "Promptify installation complete. Restart your session and run /promptify."

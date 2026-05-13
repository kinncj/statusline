#!/usr/bin/env bash
# Shared helpers for per-tool installers. Sourced, not executed.
#
# Expects these env vars from install.sh:
#   REPO_DIR, STATUSLINE_SRC, DRY_RUN, UNINSTALL

# Pull in the TUI helpers (colors, logging, boxes). Per-installer scripts get
# `ok` / `warn` / `err` / `info` as the indented variants from _tui.sh.
_TUI="$(dirname "${BASH_SOURCE[0]}")/_tui.sh"
# shellcheck source=installers/_tui.sh
source "$_TUI"

# Per-installer files used unindented helpers historically. Map the old names
# to the indented variants so existing call sites render correctly inside the
# section box.
ok()   { iok   "$@"; }
warn() { iwarn "$@"; }
err()  { ierr  "$@"; }
info() { iinfo "$@"; }

# run <cmd...>: print + execute, or just print in dry-run
run() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "would: $*"
    else
        "$@"
    fi
}

# copy_statusline <dest-path>: install statusline.sh into target location
copy_statusline() {
    local dest="$1"
    local destdir
    destdir="$(dirname "$dest")"
    run mkdir -p "$destdir"
    run cp "$STATUSLINE_SRC" "$dest"
    run chmod +x "$dest"
    ok "statusline installed at $dest"
}

# remove_path <path>: rm -f with dry-run support
remove_path() {
    if [ -e "$1" ]; then
        run rm -f "$1"
        ok "removed $1"
    else
        info "nothing to remove at $1"
    fi
}

# json_set <file> [jq-flags...] <jq-expression>: update or create a JSON file
# Creates {} if file is missing or empty. The LAST arg is the jq expression;
# everything between $file and the expression is forwarded as jq flags
# (e.g. --arg cmd /path).
json_set() {
    local file="$1"; shift
    # Split remaining args: last is the expression, rest are jq flags
    local n=$#
    local expr="${!n}"
    local jq_flags=()
    if [ "$n" -gt 1 ]; then
        jq_flags=("${@:1:$((n-1))}")
    fi

    local tmp
    tmp="$(mktemp)"
    # Bash 3.2 (macOS /bin/bash) treats "${empty_array[@]}" as unbound under
    # `set -u`, so branch on length rather than splatting unconditionally.
    if [ "${#jq_flags[@]}" -gt 0 ]; then
        if [ -s "$file" ]; then
            jq "${jq_flags[@]}" "$expr" "$file" > "$tmp"
        else
            echo '{}' | jq "${jq_flags[@]}" "$expr" > "$tmp"
        fi
    else
        if [ -s "$file" ]; then
            jq "$expr" "$file" > "$tmp"
        else
            echo '{}' | jq "$expr" > "$tmp"
        fi
    fi

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "would write $file:"
        sed 's/^/    /' "$tmp"
        rm -f "$tmp"
    else
        mkdir -p "$(dirname "$file")"
        mv "$tmp" "$file"
        ok "updated $file"
    fi
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        err "jq is required for this installer. Install with: pacman -S jq / apt install jq / brew install jq"
        return 1
    fi
}

# install_agents_md <dest-dir>: copy repo AGENTS.md into a tool's config dir
install_agents_md() {
    local destdir="$1"
    local src="${REPO_DIR}/AGENTS.md"
    if [ ! -f "$src" ]; then
        warn "AGENTS.md not in repo, skipping"
        return 0
    fi
    run mkdir -p "$destdir"
    run cp "$src" "$destdir/AGENTS.md"
    ok "AGENTS.md installed at $destdir/AGENTS.md"
}

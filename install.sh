#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kinn Coelho Juliao <kinncj@protonmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Portable installer for the kinncj statusline.
#
# Targets (auto-detected on $PATH unless --target is passed):
#   claude-code     Wire ~/.claude/settings.json -> statusline.sh
#   opencode        Wire ~/.config/opencode/opencode.json
#   copilot-cli     Wire ~/.copilot/settings.json (newer github/copilot-cli only)
#   pi              No statusline hook; just place AGENTS.md (and skills) in ~/.pi/agent/
#   hermes          No statusline hook; just place AGENTS.md / skills in ~/.hermes/
#
# Usage:
#   ./install.sh                     # interactive, installs to all detected tools
#   ./install.sh --all               # non-interactive, all detected
#   ./install.sh --target opencode   # one specific tool (repeatable)
#   ./install.sh --dry-run           # print what would happen, change nothing
#   ./install.sh --uninstall         # remove statusline wiring from each tool's config
#   ./install.sh --no-animation      # skip the animated logo / spinners
#   ./install.sh --quiet             # suppress logo entirely

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSLINE_SRC="${REPO_DIR}/statusline.sh"

# ── flags ─────────────────────────────────────────────────────────────────────
DRY_RUN=0
UNINSTALL=0
ALL=0
QUIET=0
TARGETS=()

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)      DRY_RUN=1 ;;
        --uninstall)    UNINSTALL=1 ;;
        --all)          ALL=1 ;;
        --quiet|-q)     QUIET=1 ;;
        --no-animation) export TUI_NO_ANIM=1 ;;
        --target)       shift; TARGETS+=("$1") ;;
        --target=*)     TARGETS+=("${1#--target=}") ;;
        -h|--help)      usage ;;
        *)              printf 'unknown flag: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

# ── load TUI helpers ──────────────────────────────────────────────────────────
# shellcheck source=installers/_tui.sh
source "${REPO_DIR}/installers/_tui.sh"

[ -f "$STATUSLINE_SRC" ] || { err "statusline.sh missing from repo at $STATUSLINE_SRC"; exit 1; }

# ── intro ─────────────────────────────────────────────────────────────────────
if [ "$QUIET" -ne 1 ]; then
    tui_logo
fi

action="install"
[ "$UNINSTALL" -eq 1 ] && action="uninstall"
[ "$DRY_RUN" -eq 1 ]   && action="${action} (dry-run)"

log "${C_BOLD}kinncj statusline${C_RESET} ${C_DIM}— ${action}${C_RESET}"
log "${C_DIM}repo:${C_RESET} ${C_CYAN}$REPO_DIR${C_RESET}"

# ── detect which tools are installed ──────────────────────────────────────────
KNOWN_TOOLS=(claude-code opencode copilot-cli pi hermes)

detect() {
    case "$1" in
        claude-code)  command -v claude       >/dev/null 2>&1 ;;
        opencode)     command -v opencode     >/dev/null 2>&1 ;;
        copilot-cli)  command -v copilot      >/dev/null 2>&1 ;;
        pi)           command -v pi           >/dev/null 2>&1 ;;
        hermes)       command -v hermes       >/dev/null 2>&1 ;;
        *)            return 1 ;;
    esac
}

# ── decide target list ────────────────────────────────────────────────────────
if [ "${#TARGETS[@]}" -eq 0 ]; then
    detected=()
    for t in "${KNOWN_TOOLS[@]}"; do
        detect "$t" && detected+=("$t")
    done

    if [ "${#detected[@]}" -eq 0 ]; then
        log ""
        warn "no supported CLIs detected on \$PATH"
        info "supported: ${KNOWN_TOOLS[*]}"
        info "use --target <name> to install anyway"
        exit 0
    fi

    log ""
    log "${C_DIM}detected:${C_RESET} ${C_CYAN}${detected[*]}${C_RESET}"

    if [ "$ALL" -eq 1 ] || [ ! -t 0 ]; then
        TARGETS=("${detected[@]}")
    else
        printf '%b? %binstall for all detected? [Y/n] ' "$C_BOLD" "$C_RESET"
        read -r reply
        case "${reply:-y}" in
            [Yy]*|"") TARGETS=("${detected[@]}") ;;
            *)        err "aborted"; exit 1 ;;
        esac
    fi
fi

# ── dispatch ──────────────────────────────────────────────────────────────────
export REPO_DIR STATUSLINE_SRC DRY_RUN UNINSTALL TUI_NO_ANIM

exit_code=0
declare -a SUMMARY_TOOL SUMMARY_STATUS SUMMARY_DETAIL

for tool in "${TARGETS[@]}"; do
    installer="${REPO_DIR}/installers/${tool}.sh"
    tui_section "${tool}" 60
    if [ ! -x "$installer" ]; then
        tui_box_bot 60
        ierr "no installer for '${tool}' (expected ${installer})"
        SUMMARY_TOOL+=("$tool")
        SUMMARY_STATUS+=("fail")
        SUMMARY_DETAIL+=("missing installer")
        exit_code=1
        continue
    fi
    if bash "$installer"; then
        tui_box_bot 60
        SUMMARY_TOOL+=("$tool")
        SUMMARY_STATUS+=("ok")
        SUMMARY_DETAIL+=("$action")
    else
        tui_box_bot 60
        ierr "${tool} installer failed"
        SUMMARY_TOOL+=("$tool")
        SUMMARY_STATUS+=("fail")
        SUMMARY_DETAIL+=("installer returned non-zero")
        exit_code=1
    fi
done

# ── summary ───────────────────────────────────────────────────────────────────
log ""
tui_box_top 60 "summary"
i=0
while [ "$i" -lt "${#SUMMARY_TOOL[@]}" ]; do
    tui_summary_row "${SUMMARY_TOOL[$i]}" "${SUMMARY_STATUS[$i]}" "${SUMMARY_DETAIL[$i]}"
    i=$((i+1))
done
tui_box_bot 60

exit $exit_code

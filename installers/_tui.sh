#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kinn Coelho Juliao <kinncj@protonmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
# Shared TUI helpers: colors, box-drawing, animated logo, section banners.
# Sourced (not executed) by install.sh.
#
# Some color vars (C_BLUE, C_MAGENTA, C_WHITE) are part of the palette
# exposed to per-installer scripts even though _tui.sh itself doesn't use
# every one. Silence shellcheck's unused-variable warning for the file.
# shellcheck disable=SC2034
#
# Honors:
#   - NO_COLOR    (https://no-color.org) — disables color
#   - TUI_NO_ANIM (set to 1) — skips animations, prints final frames instantly
#   - non-TTY stdout — auto-disables color and animation

# ── color setup ──────────────────────────────────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'
    C_DIM=$'\033[2m'
    C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_MAGENTA=$'\033[35m'
    C_CYAN=$'\033[36m'
    C_WHITE=$'\033[37m'
    TUI_TTY=1
else
    C_RESET=''; C_DIM=''; C_BOLD=''
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
    C_MAGENTA=''; C_CYAN=''; C_WHITE=''
    TUI_TTY=0
fi

# Animation defaults to off when not a TTY or when TUI_NO_ANIM=1
if [ "$TUI_TTY" -eq 1 ] && [ "${TUI_NO_ANIM:-0}" -ne 1 ]; then
    TUI_ANIM=1
else
    TUI_ANIM=0
fi

# ── logging primitives ───────────────────────────────────────────────────────
log()  { printf '%b\n' "$*"; }
ok()   { log "${C_GREEN}✓${C_RESET} $*"; }
warn() { log "${C_YELLOW}!${C_RESET} $*"; }
err()  { log "${C_RED}✗${C_RESET} $*" >&2; }
info() { log "${C_DIM}·${C_RESET} $*"; }

# Indented variants for per-installer output
iok()   { log "  ${C_GREEN}✓${C_RESET} $*"; }
iwarn() { log "  ${C_YELLOW}!${C_RESET} $*"; }
ierr()  { log "  ${C_RED}✗${C_RESET} $*" >&2; }
iinfo() { log "  ${C_DIM}·${C_RESET} $*"; }

# ── sleep wrapper that respects TUI_ANIM ─────────────────────────────────────
_nap() {
    [ "$TUI_ANIM" -eq 1 ] || return 0
    # Fractional sleep — works on GNU sleep and most BSD sleeps
    sleep "$1" 2>/dev/null || true
}

# ── retro-terminal logo ──────────────────────────────────────────────────────
# Each line is stored as raw text; render with color + optional reveal animation.
# Width: 49 cols.
_LOGO_LINES=(
    ' ██╗  ██╗██╗███╗   ██╗███╗   ██╗ ██████╗     ██╗'
    ' ██║ ██╔╝██║████╗  ██║████╗  ██║██╔════╝     ██║'
    ' █████╔╝ ██║██╔██╗ ██║██╔██╗ ██║██║          ██║'
    ' ██╔═██╗ ██║██║╚██╗██║██║╚██╗██║██║     ██   ██║'
    ' ██║  ██╗██║██║ ╚████║██║ ╚████║╚██████╗╚█████╔╝'
    ' ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═══╝ ╚═════╝ ╚════╝ '
)
_TAGLINE='        s · t · a · t · u · s · l · i · n · e'

# tui_logo: print the animated logo. With TUI_ANIM=1, reveals line-by-line
# then blinks a typing cursor at the tagline's end.
tui_logo() {
    local color="${C_CYAN}"
    local glow="${C_BOLD}${C_CYAN}"
    local line

    if [ "$TUI_ANIM" -eq 0 ]; then
        printf '\n'
        for line in "${_LOGO_LINES[@]}"; do
            printf '%b%s%b\n' "$color" "$line" "$C_RESET"
        done
        printf '%b%s_%b\n\n' "$C_DIM" "$_TAGLINE" "$C_RESET"
        return
    fi

    printf '\n'
    for line in "${_LOGO_LINES[@]}"; do
        printf '%b%s%b\n' "$glow" "$line" "$C_RESET"
        _nap 0.045
    done

    # Type out the tagline character-by-character with a blinking cursor.
    printf '%b' "$C_DIM"
    local i len="${#_TAGLINE}"
    for (( i=0; i<len; i++ )); do
        printf '%s' "${_TAGLINE:$i:1}"
        _nap 0.012
    done
    printf '%b' "$C_RESET"

    # Cursor blink: 3 cycles
    local n
    for n in 1 2 3; do
        printf '%b_%b' "$C_BOLD$C_CYAN" "$C_RESET"
        _nap 0.18
        printf '\b \b'
        _nap 0.18
    done
    printf '%b_%b\n\n' "$C_DIM" "$C_RESET"
}

# ── box drawing ──────────────────────────────────────────────────────────────
# tui_box_top <width> [title]
# tui_box_bot <width>
# tui_box_section <title>  (full single-line section banner: top, title, bot)
_repeat() {
    # repeat <char> <count>
    local ch="$1" n="$2" out=''
    while [ "$n" -gt 0 ]; do out="${out}${ch}"; n=$((n-1)); done
    printf '%s' "$out"
}

tui_box_top() {
    local width="${1:-50}" title="${2:-}"
    local color="${C_CYAN}"
    if [ -z "$title" ]; then
        printf '%b╔%s╗%b\n' "$color" "$(_repeat '═' $((width-2)))" "$C_RESET"
        return
    fi
    # Box top with embedded title: ╔══ title ══════╗
    # Total width = 1(╔) + 2(══) + len(label) + pad + 1(╗)  =>  pad = width - len - 4
    local label=" ${title} "
    local pad=$((width - ${#label} - 4))
    [ "$pad" -lt 0 ] && pad=0
    printf '%b╔══%b%s%b%s%b╗%b\n' \
        "$color" "$C_BOLD$C_WHITE" "$label" "$C_RESET$color" \
        "$(_repeat '═' "$pad")" "$color" "$C_RESET"
}

tui_box_bot() {
    local width="${1:-50}"
    printf '%b╚%s╝%b\n' "$C_CYAN" "$(_repeat '═' $((width-2)))" "$C_RESET"
}

# Inline section banner used between per-tool installer runs.
tui_section() {
    local title="$1"
    local width="${2:-60}"
    printf '\n'
    tui_box_top "$width" "$title"
}

# ── spinner ──────────────────────────────────────────────────────────────────
# tui_spinner_start <message>; ...work...; tui_spinner_stop <ok|fail> [message]
_SPIN_PID=''
tui_spinner_start() {
    local msg="$1"
    if [ "$TUI_ANIM" -eq 0 ]; then
        printf '  %b·%b %s ... ' "$C_DIM" "$C_RESET" "$msg"
        return
    fi
    (
        local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        local i=0
        while :; do
            local ch="${frames:$((i % ${#frames})):1}"
            printf '\r  %b%s%b %s' "$C_CYAN" "$ch" "$C_RESET" "$msg"
            i=$((i+1))
            sleep 0.08
        done
    ) &
    _SPIN_PID=$!
    disown 2>/dev/null || true
}

tui_spinner_stop() {
    local status="${1:-ok}" msg="${2:-}"
    if [ -n "$_SPIN_PID" ]; then
        kill "$_SPIN_PID" 2>/dev/null || true
        wait "$_SPIN_PID" 2>/dev/null || true
        _SPIN_PID=''
        printf '\r\033[K'  # clear the spinner line
    fi
    case "$status" in
        ok)   printf '  %b✓%b %s\n' "$C_GREEN" "$C_RESET" "$msg" ;;
        fail) printf '  %b✗%b %s\n' "$C_RED"   "$C_RESET" "$msg" ;;
        *)    printf '  %b·%b %s\n' "$C_DIM"   "$C_RESET" "$msg" ;;
    esac
}

# ── summary table ────────────────────────────────────────────────────────────
# tui_summary_row <tool> <status> [detail]
#   status: ok | fail | skip
tui_summary_row() {
    local tool="$1" status="$2" detail="${3:-}"
    local mark color
    case "$status" in
        ok)   mark='✓'; color="$C_GREEN" ;;
        fail) mark='✗'; color="$C_RED" ;;
        skip) mark='–'; color="$C_DIM" ;;
        *)    mark='?'; color="$C_YELLOW" ;;
    esac
    printf '  %b%s%b  %-14s %b%s%b\n' \
        "$color" "$mark" "$C_RESET" "$tool" "$C_DIM" "$detail" "$C_RESET"
}

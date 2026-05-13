#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kinn Coelho Juliao <kinncj@protonmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
# GitHub Copilot CLI: ~/.copilot/config.json -> statusLine.command
#
# Verified against Copilot CLI 1.0.46 and griches/copilot-hud's setup skill:
#   - statusLine config lives in ~/.copilot/config.json (NOT settings.json,
#     despite that file's misleading "User settings belong in settings.json"
#     header — that comment refers to a different class of settings; the
#     statusLine reader only looks at config.json).
#   - Requires Copilot launched with --experimental, OR `"experimental": true`
#     persisted in config.json (we set the latter so users don't need the flag).
#   - command path must be absolute and the script must be executable with a
#     valid shebang. ~ and env vars are NOT expanded.
#   - config.json is auto-managed by Copilot and starts with `//` comment lines
#     that are not valid JSON; we strip them before piping to jq.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
require_jq || exit 1

COPILOT_HOME="${COPILOT_HOME:-$HOME/.copilot}"
CONFIG="${COPILOT_HOME}/config.json"
SETTINGS="${COPILOT_HOME}/settings.json"
DEST="${COPILOT_HOME}/statusline.sh"

# json_set_stripped <file> [jq-flags...] <expr>
# Like json_set but tolerates leading // comments (Copilot's config.json header).
json_set_stripped() {
    local file="$1"; shift
    local n=$#
    local expr="${!n}"
    local jq_flags=()
    [ "$n" -gt 1 ] && jq_flags=("${@:1:$((n-1))}")

    local tmp; tmp="$(mktemp)"
    local stripped; stripped="$(mktemp)"
    if [ -s "$file" ]; then
        sed 's|^//.*||' "$file" > "$stripped"
    else
        echo '{}' > "$stripped"
    fi

    if [ "${#jq_flags[@]}" -gt 0 ]; then
        jq "${jq_flags[@]}" "$expr" "$stripped" > "$tmp"
    else
        jq "$expr" "$stripped" > "$tmp"
    fi
    rm -f "$stripped"

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

if [ "${UNINSTALL:-0}" -eq 1 ]; then
    [ -f "$CONFIG" ] && json_set_stripped "$CONFIG" 'del(.statusLine)'
    # Clean up dead keys older versions of this installer wrote to settings.json.
    [ -f "$SETTINGS" ] && json_set "$SETTINGS" 'del(.statusLine) | del(.footer) | del(.experimental)'
    remove_path "$DEST"
    exit 0
fi

copy_statusline "$DEST"

# shellcheck disable=SC2016  # $cmd is a jq variable bound by --arg, not bash
json_set_stripped "$CONFIG" \
    --arg cmd "$DEST" \
    '.statusLine = {type: "command", command: $cmd, padding: 1} | .experimental = true'

# Migration: scrub the dead statusLine/footer keys older installer versions
# wrote into settings.json. Copilot doesn't read them there, so they're noise.
if [ -f "$SETTINGS" ]; then
    json_set "$SETTINGS" 'del(.statusLine) | del(.footer)'
fi

ok "copilot-cli wired"
info "experimental:true is persisted in config.json, so plain 'copilot' picks it up"
info "(launching with --experimental works too; both toggle the same feature gate)"

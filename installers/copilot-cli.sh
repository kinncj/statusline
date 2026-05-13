#!/usr/bin/env bash
# GitHub Copilot CLI: ~/.copilot/settings.json -> statusLine.command
#
# Schema is shipped (confirmed against github/copilot-cli changelog):
#   - User settings live in ~/.copilot/settings.json (separate from internal
#     state in ~/.copilot/config.json).
#   - statusLine.command supports ~ and env vars.
#   - The /statusline slash command (alias /footer) toggles which built-in
#     items appear and whether the custom command output is visible.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
require_jq || exit 1

COPILOT_HOME="${COPILOT_HOME:-$HOME/.copilot}"
SETTINGS="${COPILOT_HOME}/settings.json"
DEST="${COPILOT_HOME}/statusline.sh"

if [ "${UNINSTALL:-0}" -eq 1 ]; then
    [ -f "$SETTINGS" ] && json_set "$SETTINGS" 'del(.statusLine)'
    remove_path "$DEST"
    exit 0
fi

copy_statusline "$DEST"

# Copilot CLI statusLine schema:
#   { "type": "command", "command": "/path/to/script", "padding": 1 }
# shellcheck disable=SC2016  # $cmd is a jq variable bound by --arg, not bash
json_set "$SETTINGS" \
    --arg cmd "$DEST" \
    '.statusLine = {type: "command", command: $cmd, padding: 1}'

ok "copilot-cli wired"
info "inside copilot run /statusline to toggle the custom command line on"

#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kinn Coelho Juliao <kinncj@protonmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
# Claude Code: ~/.claude/settings.json -> statusLine.command
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
require_jq || exit 1

CLAUDE_DIR="${HOME}/.claude"
SETTINGS="${CLAUDE_DIR}/settings.json"
DEST="${CLAUDE_DIR}/statusline-command.sh"

if [ "${UNINSTALL:-0}" -eq 1 ]; then
    [ -f "$SETTINGS" ] && json_set "$SETTINGS" 'del(.statusLine)'
    remove_path "$DEST"
    exit 0
fi

copy_statusline "$DEST"

# Claude Code statusLine schema:
#   { "type": "command", "command": "/path/to/script", "padding": 1 }
# shellcheck disable=SC2016  # $cmd is a jq variable bound by --arg, not bash
json_set "$SETTINGS" \
    --arg cmd "$DEST" \
    '.statusLine = {type: "command", command: $cmd, padding: 1}'

ok "claude-code wired"
info "restart Claude Code or run /status to see the new line"

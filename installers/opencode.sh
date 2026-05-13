#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kinn Coelho Juliao <kinncj@protonmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
# OpenCode: ~/.config/opencode/opencode.json -> statusline.command
# Reference: https://opencode.ai/docs/config/
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
require_jq || exit 1

CFG_DIR="${HOME}/.config/opencode"
SETTINGS="${CFG_DIR}/opencode.json"
DEST="${CFG_DIR}/statusline.sh"

if [ "${UNINSTALL:-0}" -eq 1 ]; then
    [ -f "$SETTINGS" ] && json_set "$SETTINGS" 'del(.statusline) | del(.experimental.statusline)'
    remove_path "$DEST"
    exit 0
fi

copy_statusline "$DEST"

# OpenCode does NOT yet ship a script-driven statusline — tracked as an open
# feature request at anomalyco/opencode#8619. We write the two key shapes
# that have been proposed (top-level "statusline" and "experimental.statusline")
# so that whichever the runtime eventually adopts will pick it up without a
# re-install. Until shipped, this is dead JSON; the AGENTS.md drop is what
# actually carries weight.
# shellcheck disable=SC2016  # $schema and $cmd are jq variables bound by --arg
json_set "$SETTINGS" \
    --arg schema "https://opencode.ai/config.json" \
    --arg cmd "$DEST" \
    '. + {
        "$schema": $schema,
        "statusline": {"command": $cmd},
        "experimental": (.experimental // {} | . + {"statusline": {"command": $cmd}})
    }'

ok "opencode wired"
info "restart opencode to pick up the new statusline"

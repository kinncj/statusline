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
# feature request at anomalyco/opencode#8619. Earlier versions of this
# installer speculatively wrote `statusline` and `experimental.statusline`
# config keys; opencode's schema is strict and now refuses to start when
# unknown keys are present, so we no longer write them. If a prior install
# left those keys behind, strip them so opencode boots again. The AGENTS.md
# drop is what actually carries weight today.
if [ -f "$SETTINGS" ] && jq -e '.statusline? // .experimental.statusline?' "$SETTINGS" >/dev/null 2>&1; then
    info "removing legacy speculative statusline keys from $SETTINGS"
    json_set "$SETTINGS" 'del(.statusline) | del(.experimental.statusline) | if .experimental == {} then del(.experimental) else . end'
fi

warn "opencode upstream has NOT shipped a statusline hook yet"
info "tracking issue: https://github.com/anomalyco/opencode/issues/8619"
info "statusline.sh is installed at $DEST and ready for when upstream ships the hook"
info "today, opencode renders its built-in footer; AGENTS.md is the active surface"
ok "opencode statusline staged (pending upstream)"

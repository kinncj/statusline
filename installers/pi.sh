#!/usr/bin/env bash
# Pi (pi.dev): no Claude-Code-style command-hook for the statusline.
#
# Pi customizes its footer through the npm extension system:
#   pi install npm:pi-powerline-footer         # rich preset-based footer
#   pi install npm:pi-bar                      # compact model/context bar
#   pi install npm:pi-side-agents              # per-agent tmux-window indicator
#
# We can't wire our shell statusline.sh into Pi the way we do for Claude.
# What we *can* do: drop AGENTS.md so Pi picks up repo instructions, and
# point the user at the right npm package if they want a richer footer.
# Reference: https://pi.dev/docs/latest/
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

PI_DIR="${HOME}/.pi/agent"

if [ "${UNINSTALL:-0}" -eq 1 ]; then
    remove_path "${PI_DIR}/AGENTS.md"
    exit 0
fi

info "pi customizes its footer via npm extensions, not a shell-command hook"
info "for a rich statusline, run: pi install npm:pi-powerline-footer"
install_agents_md "$PI_DIR"

ok "pi configured (AGENTS.md installed)"

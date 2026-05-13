#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kinn Coelho Juliao <kinncj@protonmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
# Pi (pi.dev): native extension via ~/.pi/agent/extensions/.
#
# Pi auto-discovers extension files in `<agentDir>/extensions/`. We drop a
# tiny JS shell-bridge extension (extensions/pi/statusline.mjs) that pipes
# Pi's session context to our statusline.sh and renders the result as a
# widget below the editor — same template as Claude Code / Copilot CLI,
# no per-host fork.
#
# Pi's own rich footer (cwd · branch · token stats · model) stays as-is;
# our widget sits below it. Two complementary lines instead of one.
#
# Reference: ExtensionAPI lives under @earendil-works/pi-coding-agent
# (formerly @mariozechner/pi-coding-agent). Verified against pi 0.73.1.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

PI_DIR="${HOME}/.pi/agent"
EXT_DIR="${PI_DIR}/extensions/kinncj-statusline"
SRC_EXT_DIR="${REPO_DIR}/extensions/pi"
SRC_EXT="${SRC_EXT_DIR}/statusline.mjs"
SRC_MANIFEST="${SRC_EXT_DIR}/package.json"

if [ "${UNINSTALL:-0}" -eq 1 ]; then
    # remove_path only handles regular files; the extension package is a dir.
    if [ -d "$EXT_DIR" ]; then
        run rm -rf "$EXT_DIR"
        ok "removed $EXT_DIR"
    else
        info "nothing to remove at $EXT_DIR"
    fi
    remove_path "${PI_DIR}/AGENTS.md"
    exit 0
fi

# 1. Install the extension package. Pi's discovery (loader.js in
#    @earendil-works/pi-coding-agent 0.73.1) only matches `.ts`/`.js`
#    files directly, or a subdir with `index.{ts,js}` or a `package.json`
#    declaring `pi.extensions`. We ship the manifest form so the
#    `.mjs` filename keeps its descriptive name. The sibling
#    `statusline.sh` is dropped here too so the extension's
#    `import.meta.url`-relative lookup resolves locally.
run mkdir -p "$EXT_DIR"
run cp "$SRC_MANIFEST" "$EXT_DIR/package.json"
run cp "$SRC_EXT" "$EXT_DIR/statusline.mjs"
run cp "$STATUSLINE_SRC" "$EXT_DIR/statusline.sh"
run chmod +x "$EXT_DIR/statusline.sh"
ok "pi extension installed at $EXT_DIR/"

# 2. AGENTS.md so Pi picks up repo instructions automatically.
install_agents_md "$PI_DIR"

ok "pi wired (extension + AGENTS.md)"
info "Pi will auto-discover the extension on next launch; no settings to edit"

#!/usr/bin/env bash
# Hermes (nousresearch/hermes-agent): full TUI, no scriptable statusline.
# Install AGENTS.md to ~/.hermes/ so Hermes picks up repo instructions globally.
# Reference: https://github.com/nousresearch/hermes-agent
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

HERMES_DIR="${HOME}/.hermes"
SKILLS_DIR="${HERMES_DIR}/skills"

if [ "${UNINSTALL:-0}" -eq 1 ]; then
    remove_path "${HERMES_DIR}/AGENTS.md"
    remove_path "${SKILLS_DIR}/statusline-edit.md"
    exit 0
fi

warn "hermes-agent has no script-driven statusline (built-in TUI only)"
info "installing AGENTS.md and statusline skill so Hermes picks them up"
install_agents_md "$HERMES_DIR"

# Hermes uses the agentskills.io standard — same markdown format we already use.
SKILL_SRC="${REPO_DIR}/.claude/skills/statusline-edit.md"
if [ -f "$SKILL_SRC" ]; then
    run mkdir -p "$SKILLS_DIR"
    run cp "$SKILL_SRC" "${SKILLS_DIR}/statusline-edit.md"
    ok "skill installed at ${SKILLS_DIR}/statusline-edit.md"
fi

ok "hermes configured (AGENTS.md + skill, no statusline)"

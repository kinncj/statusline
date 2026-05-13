#!/usr/bin/env bats
# Tests for installers/pi.sh and installers/hermes.sh — both are
# AGENTS.md-only (no script-driven statusline).

load test_helper

setup()    { setup_fake_home; }
teardown() { teardown_fake_home; }

@test "pi: install drops AGENTS.md into ~/.pi/agent/" {
    run_installer pi
    [ "$status" -eq 0 ]
    [ -f "$HOME/.pi/agent/AGENTS.md" ]
    # Sanity: it's the real one, not an empty stub.
    grep -q 'kinncj statusline' "$HOME/.pi/agent/AGENTS.md"
}

@test "pi: uninstall removes AGENTS.md" {
    run_installer pi
    [ -f "$HOME/.pi/agent/AGENTS.md" ]
    UNINSTALL=1 run_installer pi
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.pi/agent/AGENTS.md" ]
}

@test "hermes: install drops AGENTS.md and statusline-edit skill" {
    run_installer hermes
    [ "$status" -eq 0 ]
    [ -f "$HOME/.hermes/AGENTS.md" ]
    # Skill only ships if the source file exists in the repo.
    if [ -f "$REPO_ROOT/.claude/skills/statusline-edit.md" ]; then
        [ -f "$HOME/.hermes/skills/statusline-edit.md" ]
    fi
}

@test "hermes: uninstall removes AGENTS.md and skill" {
    run_installer hermes
    UNINSTALL=1 run_installer hermes
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.hermes/AGENTS.md" ]
    [ ! -e "$HOME/.hermes/skills/statusline-edit.md" ]
}

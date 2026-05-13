#!/usr/bin/env bats
# Tests for installers/pi.sh and installers/hermes.sh — both are
# AGENTS.md-only (no script-driven statusline).

load test_helper

setup()    { setup_fake_home; }
teardown() { teardown_fake_home; }

@test "pi: install drops the extension package and AGENTS.md" {
    run_installer pi
    [ "$status" -eq 0 ]
    # Pi's loader requires either index.{ts,js} or a package.json manifest
    # with pi.extensions[]. We ship the manifest form so the .mjs keeps
    # its descriptive name; without the manifest the file is silently
    # skipped at discovery time.
    [ -f "$HOME/.pi/agent/extensions/kinncj-statusline/package.json" ]
    [ -f "$HOME/.pi/agent/extensions/kinncj-statusline/statusline.mjs" ]
    [ -x "$HOME/.pi/agent/extensions/kinncj-statusline/statusline.sh" ]
    [ -f "$HOME/.pi/agent/AGENTS.md" ]
    grep -q 'kinncj statusline' "$HOME/.pi/agent/AGENTS.md"
    grep -q 'export default function' "$HOME/.pi/agent/extensions/kinncj-statusline/statusline.mjs"
    # Sanity: manifest declares the .mjs as a pi extension entry.
    run jq_get "$HOME/.pi/agent/extensions/kinncj-statusline/package.json" '.pi.extensions[0]'
    [ "$output" = "statusline.mjs" ]
    run jq_get "$HOME/.pi/agent/extensions/kinncj-statusline/package.json" '.type'
    [ "$output" = "module" ]
}

@test "pi: uninstall removes the extension and AGENTS.md" {
    run_installer pi
    [ -d "$HOME/.pi/agent/extensions/kinncj-statusline" ]
    UNINSTALL=1 run_installer pi
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.pi/agent/extensions/kinncj-statusline" ]
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

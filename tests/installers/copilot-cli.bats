#!/usr/bin/env bats
# Tests for installers/copilot-cli.sh

load test_helper

setup()    { setup_fake_home; }
teardown() { teardown_fake_home; }

@test "copilot-cli: install writes statusLine config" {
    run_installer copilot-cli
    [ "$status" -eq 0 ]
    [ -x "$HOME/.copilot/statusline.sh" ]
    run jq_get "$HOME/.copilot/settings.json" '.statusLine.type'
    [ "$output" = "command" ]
    run jq_get "$HOME/.copilot/settings.json" '.statusLine.command'
    [ "$output" = "$HOME/.copilot/statusline.sh" ]
}

@test "copilot-cli: COPILOT_HOME override is honored" {
    custom="$(mktemp -d)"
    COPILOT_HOME="$custom" run_installer copilot-cli
    [ "$status" -eq 0 ]
    [ -x "$custom/statusline.sh" ]
    [ -f "$custom/settings.json" ]
    rm -rf "$custom"
}

@test "copilot-cli: uninstall removes statusLine and script" {
    run_installer copilot-cli
    UNINSTALL=1 run_installer copilot-cli
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.copilot/statusline.sh" ]
    run jq_get "$HOME/.copilot/settings.json" '.statusLine'
    [ "$output" = "null" ]
}

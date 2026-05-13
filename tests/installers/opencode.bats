#!/usr/bin/env bats
# Tests for installers/opencode.sh

load test_helper

setup()    { setup_fake_home; }
teardown() { teardown_fake_home; }

@test "opencode: install writes both statusline and experimental.statusline" {
    run_installer opencode
    [ "$status" -eq 0 ]
    [ -x "$HOME/.config/opencode/statusline.sh" ]
    [ -f "$HOME/.config/opencode/opencode.json" ]
    run jq_get "$HOME/.config/opencode/opencode.json" '.statusline.command'
    [ "$output" = "$HOME/.config/opencode/statusline.sh" ]
    run jq_get "$HOME/.config/opencode/opencode.json" '.experimental.statusline.command'
    [ "$output" = "$HOME/.config/opencode/statusline.sh" ]
    run jq_get "$HOME/.config/opencode/opencode.json" '."$schema"'
    [ "$output" = "https://opencode.ai/config.json" ]
}

@test "opencode: dry-run leaves filesystem untouched" {
    DRY_RUN=1 run_installer opencode
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.config/opencode/opencode.json" ]
    [ ! -e "$HOME/.config/opencode/statusline.sh" ]
}

@test "opencode: uninstall strips both statusline keys" {
    run_installer opencode
    [ -f "$HOME/.config/opencode/opencode.json" ]
    UNINSTALL=1 run_installer opencode
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.config/opencode/statusline.sh" ]
    run jq_get "$HOME/.config/opencode/opencode.json" '.statusline'
    [ "$output" = "null" ]
    run jq_get "$HOME/.config/opencode/opencode.json" '.experimental.statusline'
    [ "$output" = "null" ]
}

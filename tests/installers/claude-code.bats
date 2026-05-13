#!/usr/bin/env bats
# Tests for installers/claude-code.sh

load test_helper

setup()    { setup_fake_home; }
teardown() { teardown_fake_home; }

@test "claude-code: dry-run does not write any files" {
    DRY_RUN=1 run_installer claude-code
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.claude/settings.json" ]
    [ ! -e "$HOME/.claude/statusline-command.sh" ]
}

@test "claude-code: install copies statusline.sh and writes settings.json" {
    run_installer claude-code
    [ "$status" -eq 0 ]
    [ -x "$HOME/.claude/statusline-command.sh" ]
    [ -f "$HOME/.claude/settings.json" ]
    run jq_get "$HOME/.claude/settings.json" '.statusLine.type'
    [ "$output" = "command" ]
    run jq_get "$HOME/.claude/settings.json" '.statusLine.command'
    [ "$output" = "$HOME/.claude/statusline-command.sh" ]
    run jq_get "$HOME/.claude/settings.json" '.statusLine.padding'
    [ "$output" = "1" ]
}

@test "claude-code: install is idempotent — running twice yields same config" {
    run_installer claude-code
    [ "$status" -eq 0 ]
    first_hash="$(sha256sum "$HOME/.claude/settings.json" | awk '{print $1}')"
    run_installer claude-code
    [ "$status" -eq 0 ]
    second_hash="$(sha256sum "$HOME/.claude/settings.json" | awk '{print $1}')"
    [ "$first_hash" = "$second_hash" ]
}

@test "claude-code: install preserves unrelated settings.json keys" {
    mkdir -p "$HOME/.claude"
    echo '{"theme":"dark","other":42}' > "$HOME/.claude/settings.json"
    run_installer claude-code
    [ "$status" -eq 0 ]
    run jq_get "$HOME/.claude/settings.json" '.theme'
    [ "$output" = "dark" ]
    run jq_get "$HOME/.claude/settings.json" '.other'
    [ "$output" = "42" ]
}

@test "claude-code: uninstall removes statusLine and the script" {
    run_installer claude-code
    [ -f "$HOME/.claude/settings.json" ]
    UNINSTALL=1 run_installer claude-code
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.claude/statusline-command.sh" ]
    run jq_get "$HOME/.claude/settings.json" '.statusLine'
    [ "$output" = "null" ]
}

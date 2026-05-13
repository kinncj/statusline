#!/usr/bin/env bats
# End-to-end tests for the top-level install.sh dispatcher.

load test_helper

setup()    { setup_fake_home; }
teardown() { teardown_fake_home; }

@test "install: --help prints usage and exits 0" {
    run_install --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Portable installer" ]]
    [[ "$output" =~ "--dry-run" ]]
}

@test "install: unknown flag exits non-zero" {
    run_install --bogus-flag
    [ "$status" -ne 0 ]
}

@test "install: --target with --dry-run does not touch filesystem" {
    run_install --dry-run --target claude-code
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.claude/settings.json" ]
    [[ "$output" =~ "claude-code" ]]
    [[ "$output" =~ "would:" ]]
    [[ "$output" =~ "summary" ]]
}

@test "install: --quiet suppresses the logo" {
    run_install --quiet --dry-run --target claude-code
    [ "$status" -eq 0 ]
    # The retro-terminal logo always contains these box chars.
    [[ ! "$output" =~ "██╗" ]]
}

@test "install: logo is rendered when not --quiet" {
    run_install --no-animation --dry-run --target claude-code
    [ "$status" -eq 0 ]
    [[ "$output" =~ "██╗" ]]
    [[ "$output" =~ "s · t · a · t · u · s · l · i · n · e" ]]
}

@test "install: multi-target dry-run lists every requested tool" {
    run_install --dry-run \
        --target claude-code --target opencode --target copilot-cli \
        --target pi --target hermes
    [ "$status" -eq 0 ]
    for tool in claude-code opencode copilot-cli pi hermes; do
        [[ "$output" =~ $tool ]]
    done
}

@test "install: real install + uninstall round-trip leaves no statusline wiring" {
    run_install --target claude-code --target opencode --target copilot-cli
    [ "$status" -eq 0 ]
    [ -f "$HOME/.claude/statusline-command.sh" ]

    run_install --uninstall --target claude-code --target opencode --target copilot-cli
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.claude/statusline-command.sh" ]
    [ ! -e "$HOME/.config/opencode/statusline.sh" ]
    [ ! -e "$HOME/.copilot/statusline.sh" ]
}

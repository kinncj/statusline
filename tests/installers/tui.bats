#!/usr/bin/env bats
# Unit tests for installers/_tui.sh (box drawing, logo, helpers).

load test_helper

setup() {
    setup_fake_home
    # shellcheck source=../../installers/_tui.sh
    NO_COLOR=1 TUI_NO_ANIM=1 source "$REPO_ROOT/installers/_tui.sh"
}
teardown() { teardown_fake_home; }

@test "tui: box top and bottom share width" {
    top="$(tui_box_top 60 'hello')"
    bot="$(tui_box_bot 60)"
    # Each renders one line; strip the trailing newline by command substitution.
    [ "${#top}" = "${#bot}" ]
}

@test "tui: logo includes block-letter rows and tagline" {
    out="$(tui_logo)"
    [[ "$out" =~ "██╗" ]]
    [[ "$out" =~ "s · t · a · t · u · s · l · i · n · e" ]]
}

@test "tui: summary row formats status marks" {
    out="$(tui_summary_row 'claude-code' ok 'installed')"
    [[ "$out" =~ "✓" ]]
    [[ "$out" =~ "claude-code" ]]
    [[ "$out" =~ "installed" ]]

    out="$(tui_summary_row 'opencode' fail 'oops')"
    [[ "$out" =~ "✗" ]]
}

@test "tui: NO_COLOR makes color vars empty" {
    [ -z "$C_RED" ]
    [ -z "$C_GREEN" ]
    [ -z "$C_RESET" ]
}

#!/usr/bin/env bats
# Tests for installers/opencode.sh

load test_helper

setup()    { setup_fake_home; }
teardown() { teardown_fake_home; }

@test "opencode: install stages statusline.sh but does NOT write speculative config keys" {
    # opencode's config schema is strict and refuses to start with unknown
    # top-level keys; we used to speculatively write `statusline` /
    # `experimental.statusline` pending anomalyco/opencode#8619 and it
    # bricked startup. Install must now leave the config alone.
    run_installer opencode
    [ "$status" -eq 0 ]
    [ -x "$HOME/.config/opencode/statusline.sh" ]
    [ ! -e "$HOME/.config/opencode/opencode.json" ]
}

@test "opencode: install strips legacy speculative keys from existing config" {
    mkdir -p "$HOME/.config/opencode"
    cat > "$HOME/.config/opencode/opencode.json" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "statusline": {"command": "/old/path/statusline.sh"},
  "experimental": {"statusline": {"command": "/old/path/statusline.sh"}}
}
EOF
    run_installer opencode
    [ "$status" -eq 0 ]
    run jq_get "$HOME/.config/opencode/opencode.json" '.statusline'
    [ "$output" = "null" ]
    run jq_get "$HOME/.config/opencode/opencode.json" '.experimental'
    [ "$output" = "null" ]
    run jq_get "$HOME/.config/opencode/opencode.json" '."$schema"'
    [ "$output" = "https://opencode.ai/config.json" ]
}

@test "opencode: dry-run leaves filesystem untouched" {
    DRY_RUN=1 run_installer opencode
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.config/opencode/opencode.json" ]
    [ ! -e "$HOME/.config/opencode/statusline.sh" ]
}

@test "opencode: uninstall strips legacy statusline keys if present" {
    mkdir -p "$HOME/.config/opencode"
    cat > "$HOME/.config/opencode/opencode.json" <<EOF
{
  "statusline": {"command": "/old/path/statusline.sh"},
  "experimental": {"statusline": {"command": "/old/path/statusline.sh"}}
}
EOF
    cp /dev/null "$HOME/.config/opencode/statusline.sh"
    UNINSTALL=1 run_installer opencode
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.config/opencode/statusline.sh" ]
    run jq_get "$HOME/.config/opencode/opencode.json" '.statusline'
    [ "$output" = "null" ]
    run jq_get "$HOME/.config/opencode/opencode.json" '.experimental.statusline'
    [ "$output" = "null" ]
}

#!/usr/bin/env bats
# Tests for installers/copilot-cli.sh
#
# Copilot's statusLine is read from ~/.copilot/config.json (not settings.json,
# despite the latter file's misleading header comment). The installer also
# persists experimental:true so the feature gate is on without requiring
# `copilot --experimental` at launch.

load test_helper

setup()    { setup_fake_home; }
teardown() { teardown_fake_home; }

@test "copilot-cli: install writes statusLine config to config.json" {
    run_installer copilot-cli
    [ "$status" -eq 0 ]
    [ -x "$HOME/.copilot/statusline.sh" ]
    run jq_get "$HOME/.copilot/config.json" '.statusLine.type'
    [ "$output" = "command" ]
    run jq_get "$HOME/.copilot/config.json" '.statusLine.command'
    [ "$output" = "$HOME/.copilot/statusline.sh" ]
    run jq_get "$HOME/.copilot/config.json" '.experimental'
    [ "$output" = "true" ]
}

@test "copilot-cli: install tolerates a pre-existing config.json with // header comments" {
    # Copilot writes a config.json that starts with `// User settings belong …`
    # comment lines that aren't valid JSON. The installer must strip them
    # before piping to jq, and must preserve other auto-managed keys.
    mkdir -p "$HOME/.copilot"
    cat > "$HOME/.copilot/config.json" <<'EOF'
// User settings belong in settings.json.
// This file is managed automatically.
{
  "firstLaunchAt": "2026-01-01T00:00:00Z",
  "trustedFolders": ["/some/path"]
}
EOF
    run_installer copilot-cli
    [ "$status" -eq 0 ]
    run jq_get "$HOME/.copilot/config.json" '.firstLaunchAt'
    [ "$output" = "2026-01-01T00:00:00Z" ]
    run jq_get "$HOME/.copilot/config.json" '.trustedFolders[0]'
    [ "$output" = "/some/path" ]
    run jq_get "$HOME/.copilot/config.json" '.statusLine.type'
    [ "$output" = "command" ]
}

@test "copilot-cli: install scrubs dead statusLine/footer keys from settings.json" {
    # Older installer versions wrote these to settings.json where Copilot
    # ignored them. New installer should clean them up if present.
    mkdir -p "$HOME/.copilot"
    cat > "$HOME/.copilot/settings.json" <<'EOF'
{
  "model": "auto",
  "statusLine": {"type": "command", "command": "/old/path"},
  "footer": {"showCustom": true}
}
EOF
    run_installer copilot-cli
    [ "$status" -eq 0 ]
    run jq_get "$HOME/.copilot/settings.json" '.statusLine'
    [ "$output" = "null" ]
    run jq_get "$HOME/.copilot/settings.json" '.footer'
    [ "$output" = "null" ]
    # Unrelated keys preserved.
    run jq_get "$HOME/.copilot/settings.json" '.model'
    [ "$output" = "auto" ]
}

@test "copilot-cli: COPILOT_HOME override is honored" {
    custom="$(mktemp -d)"
    COPILOT_HOME="$custom" run_installer copilot-cli
    [ "$status" -eq 0 ]
    [ -x "$custom/statusline.sh" ]
    [ -f "$custom/config.json" ]
    run jq -r '.statusLine.command' "$custom/config.json"
    [ "$output" = "$custom/statusline.sh" ]
    rm -rf "$custom"
}

@test "copilot-cli: uninstall removes statusLine and script" {
    run_installer copilot-cli
    UNINSTALL=1 run_installer copilot-cli
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.copilot/statusline.sh" ]
    run jq_get "$HOME/.copilot/config.json" '.statusLine'
    [ "$output" = "null" ]
}

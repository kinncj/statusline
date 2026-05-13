#!/usr/bin/env bats
# Tests for bootstrap.sh — the curl|bash entry point.
#
# To avoid hitting GitHub, we point STATUSLINE_REPO at a local file:// URL of
# the repo itself (committed to a temp git dir) and STATUSLINE_DIR at a
# disposable directory.

load test_helper

setup() {
    setup_fake_home

    # Make a throwaway git repo by snapshotting the current working copy.
    # bootstrap.sh expects a clonable origin, so we commit everything in
    # REPO_ROOT into a fresh repo inside a temp dir.
    UPSTREAM="$(mktemp -d)"
    git -C "$UPSTREAM" init -q -b main
    # Copy repo content (excluding .git and any local cruft) into the upstream.
    rsync -a --exclude '.git' --exclude 'node_modules' --exclude 'tests/installers/*.tmp' \
        "$REPO_ROOT"/ "$UPSTREAM"/ >/dev/null
    git -C "$UPSTREAM" -c user.email=ci@example.com -c user.name=ci add -A
    git -C "$UPSTREAM" -c user.email=ci@example.com -c user.name=ci commit -q -m bootstrap-test

    export STATUSLINE_REPO="file://$UPSTREAM"
    export STATUSLINE_REF=main
    export STATUSLINE_DIR="$HOME/.local/share/kinncj-statusline"
}

teardown() {
    [ -n "${UPSTREAM:-}" ] && [ -d "$UPSTREAM" ] && rm -rf "$UPSTREAM"
    teardown_fake_home
}

@test "bootstrap: clones repo and runs install.sh --dry-run" {
    run bash "$REPO_ROOT/bootstrap.sh" --dry-run --target claude-code
    [ "$status" -eq 0 ]
    [ -d "$STATUSLINE_DIR/.git" ]
    [ -x "$STATUSLINE_DIR/install.sh" ]
    [[ "$output" =~ "would:" ]]
    # dry-run: real $HOME/.claude must remain untouched.
    [ ! -e "$HOME/.claude/settings.json" ]
}

@test "bootstrap: re-runs against an existing clone (fast-forward path)" {
    run bash "$REPO_ROOT/bootstrap.sh" --dry-run --target claude-code
    [ "$status" -eq 0 ]
    # Run again — should hit the "updating existing clone" branch and still succeed.
    run bash "$REPO_ROOT/bootstrap.sh" --dry-run --target claude-code
    [ "$status" -eq 0 ]
    [[ "$output" =~ "updating existing clone" ]]
}

@test "bootstrap: rejects invalid STATUSLINE_REPO" {
    STATUSLINE_REPO=bogusrepo run bash "$REPO_ROOT/bootstrap.sh" --dry-run --target claude-code
    [ "$status" -ne 0 ]
    [[ "$output" =~ "owner/repo or a full git URL" ]]
}

@test "bootstrap: forwards flags to install.sh" {
    run bash "$REPO_ROOT/bootstrap.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Portable installer" ]]
}

#!/usr/bin/env bash
# Shared bats helpers for installer tests.
#
# Each test runs the installer against a fresh fake $HOME so nothing leaks
# into the user's real config. Animations and colors are disabled for
# deterministic, grep-friendly output.

# Resolve the repo root once.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

# Set up a sandbox HOME for a single test.
setup_fake_home() {
    FAKE_HOME="$(mktemp -d)"
    export HOME="$FAKE_HOME"
    export TUI_NO_ANIM=1
    export NO_COLOR=1
}

teardown_fake_home() {
    if [ -n "${FAKE_HOME:-}" ] && [ -d "$FAKE_HOME" ]; then
        rm -rf "$FAKE_HOME"
    fi
}

# Run install.sh with the given args. `output` and `status` are set by bats.
run_install() {
    run bash "$REPO_ROOT/install.sh" "$@"
}

# Run a single installer script directly (bypasses install.sh dispatch).
# Required env vars are exported from REPO_ROOT.
run_installer() {
    local name="$1"; shift
    export REPO_DIR="$REPO_ROOT"
    export STATUSLINE_SRC="$REPO_ROOT/statusline.sh"
    run bash "$REPO_ROOT/installers/${name}.sh" "$@"
}

# jq accessor that fails the test with a clear message on missing/empty file.
jq_get() {
    local file="$1" expr="$2"
    [ -f "$file" ] || { echo "expected file does not exist: $file" >&2; return 1; }
    jq -r "$expr" "$file"
}

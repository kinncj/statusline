#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kinn Coelho Juliao <kinncj@protonmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
# Convenience wrapper to run the bats suite.
#
# Usage:
#   tests/run.sh                 # run all bats files
#   tests/run.sh <pattern>       # run files matching a pattern
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v bats >/dev/null 2>&1; then
    cat <<'EOF' >&2
bats is not installed.

Install one of:
  Arch / CachyOS:  sudo pacman -S bats
  Debian/Ubuntu:   sudo apt install bats
  macOS:           brew install bats-core
  npm:             npm install -g bats
EOF
    exit 127
fi

pattern="${1:-}"
if [ -n "$pattern" ]; then
    files=("$REPO_ROOT"/tests/installers/*"$pattern"*.bats)
else
    files=("$REPO_ROOT"/tests/installers/*.bats)
fi

exec bats "${files[@]}"

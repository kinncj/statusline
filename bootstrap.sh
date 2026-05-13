#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kinn Coelho Juliao <kinncj@protonmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Remote installer for the kinncj statusline.
#
# Designed to be run as:
#   curl -fsSL https://raw.githubusercontent.com/kinncj/statusline/main/bootstrap.sh | bash
#
# Clones (or updates) the repo into a stable on-disk location, then hands off
# to its install.sh. Extra arguments are forwarded to install.sh, e.g.:
#   curl -fsSL …/bootstrap.sh | bash -s -- --dry-run
#   curl -fsSL …/bootstrap.sh | bash -s -- --target claude-code
#
# Knobs (override via env):
#   STATUSLINE_REPO    git URL or owner/repo (default: kinncj/statusline)
#   STATUSLINE_REF     branch / tag / commit (default: main)
#   STATUSLINE_DIR     clone destination     (default: ~/.local/share/kinncj-statusline)

set -euo pipefail

STATUSLINE_REPO="${STATUSLINE_REPO:-kinncj/statusline}"
STATUSLINE_REF="${STATUSLINE_REF:-main}"
STATUSLINE_DIR="${STATUSLINE_DIR:-$HOME/.local/share/kinncj-statusline}"

# Normalize owner/repo shorthand into a full URL.
case "$STATUSLINE_REPO" in
    http://*|https://*|ssh://*|git://*|file://*|git@*) REPO_URL="$STATUSLINE_REPO" ;;
    */*) REPO_URL="https://github.com/${STATUSLINE_REPO}.git" ;;
    *)
        echo "STATUSLINE_REPO must be either owner/repo or a full git URL" >&2
        exit 2
        ;;
esac

need() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "missing required dependency: $1" >&2
        exit 1
    }
}

need git
need bash

echo "kinncj statusline bootstrap"
echo "  repo: $REPO_URL"
echo "  ref:  $STATUSLINE_REF"
echo "  dir:  $STATUSLINE_DIR"
echo

if [ -d "$STATUSLINE_DIR/.git" ]; then
    echo "↻ updating existing clone"
    git -C "$STATUSLINE_DIR" fetch --depth 1 origin "$STATUSLINE_REF"
    git -C "$STATUSLINE_DIR" checkout -q "$STATUSLINE_REF"
    git -C "$STATUSLINE_DIR" reset --hard "origin/$STATUSLINE_REF" 2>/dev/null \
        || git -C "$STATUSLINE_DIR" reset --hard "$STATUSLINE_REF"
else
    mkdir -p "$(dirname "$STATUSLINE_DIR")"
    echo "↓ cloning into $STATUSLINE_DIR"
    git clone --depth 1 --branch "$STATUSLINE_REF" "$REPO_URL" "$STATUSLINE_DIR"
fi

INSTALL="$STATUSLINE_DIR/install.sh"
[ -x "$INSTALL" ] || chmod +x "$INSTALL"

echo
echo "→ handing off to install.sh"
echo

# If we have no controlling TTY (the canonical curl|bash case), install.sh's
# interactive prompt is skipped and --all is implied. Otherwise pass through
# whatever the user supplied.
if [ -t 0 ]; then
    exec "$INSTALL" "$@"
else
    exec "$INSTALL" --all "$@"
fi

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

# Describe HEAD as `<tag> (<short-sha>)` when on or near a tag, else `<short-sha>`.
# Works against any clone, shallow or otherwise; tag info is best-effort.
git_describe_head() {
    local dir="$1" sha desc
    sha=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null) || return
    desc=$(git -C "$dir" describe --tags --always --exact-match HEAD 2>/dev/null) || desc=""
    if [ -n "$desc" ] && [ "$desc" != "$sha" ]; then
        printf '%s (%s)' "$desc" "$sha"
    else
        printf '%s' "$sha"
    fi
}

# Highest semver tag visible on the remote, e.g. "v0.2.2". Empty if no tags.
remote_latest_tag() {
    git ls-remote --tags --refs "$REPO_URL" 2>/dev/null \
        | awk '{print $2}' | sed 's@refs/tags/@@' \
        | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -V | tail -1
}

# Short SHA at the tip of $STATUSLINE_REF on the remote (branch or tag ref).
remote_tip_sha() {
    git ls-remote --refs "$REPO_URL" "refs/heads/${STATUSLINE_REF}" 2>/dev/null \
        | awk '{print substr($1,1,7); exit}'
}

CURRENT_DESC=""
[ -d "$STATUSLINE_DIR/.git" ] && CURRENT_DESC=$(git_describe_head "$STATUSLINE_DIR" || true)
# These are best-effort: an empty repo (e.g. test fixtures) has no tags and
# `grep`/`tail` on an empty pipeline returns non-zero, which `pipefail`
# propagates and `set -e` would otherwise turn into a fatal exit.
LATEST_TAG=$(remote_latest_tag || true)
LATEST_TIP=$(remote_tip_sha || true)

echo "kinncj statusline bootstrap"
echo "  repo:           $REPO_URL"
echo "  tracking:       $STATUSLINE_REF"
echo "  dir:            $STATUSLINE_DIR"
echo "  installed:      ${CURRENT_DESC:-(not yet installed)}"
echo "  latest release: ${LATEST_TAG:-(no semver tag)}"
[ -n "$LATEST_TIP" ] && echo "  latest commit:  $LATEST_TIP on $STATUSLINE_REF"
echo

if [ -d "$STATUSLINE_DIR/.git" ]; then
    echo "↻ updating existing clone"
    # --tags so `git describe` can resolve tag names after the reset.
    git -C "$STATUSLINE_DIR" fetch --depth 1 --tags origin "$STATUSLINE_REF"
    git -C "$STATUSLINE_DIR" checkout -q "$STATUSLINE_REF"
    git -C "$STATUSLINE_DIR" reset --hard "origin/$STATUSLINE_REF" 2>/dev/null \
        || git -C "$STATUSLINE_DIR" reset --hard "$STATUSLINE_REF"
else
    mkdir -p "$(dirname "$STATUSLINE_DIR")"
    echo "↓ cloning into $STATUSLINE_DIR"
    git clone --depth 1 --branch "$STATUSLINE_REF" "$REPO_URL" "$STATUSLINE_DIR"
    # Tag refs aren't pulled by a branch-scoped shallow clone; fetch them so
    # `git describe` can name the current commit if it landed on a tag.
    git -C "$STATUSLINE_DIR" fetch --depth 1 --tags origin >/dev/null 2>&1 || true
fi

NEW_DESC=$(git_describe_head "$STATUSLINE_DIR" || true)
if [ -z "$CURRENT_DESC" ]; then
    echo "✓ installed at $NEW_DESC"
elif [ "$CURRENT_DESC" = "$NEW_DESC" ]; then
    echo "✓ already at $NEW_DESC — re-running install"
else
    echo "↑ updated: $CURRENT_DESC → $NEW_DESC"
fi
echo

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

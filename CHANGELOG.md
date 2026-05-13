# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-12

### Added
- `statusline.sh` — portable two-line statusline for AI CLIs (Claude Code,
  OpenCode, GitHub Copilot CLI). Renders directory, git branch, model,
  thinking effort, context %% with token breakdown, ccusage cost block
  (labelled `API-est` so subscribers aren't misled), Claude.ai 5h/7d quotas,
  and session duration. Each segment self-suppresses when its source data
  isn't present.
- Copilot CLI rendering parity: context-window fallback chain
  (`used_percentage // current_context_used_percentage`,
  `context_window_size // displayed_context_limit`) keeps the block alive
  across Copilot's auto-router free-model mode where the primary fields
  go `null`; Copilot-native cost cluster
  (`💰 N reqs · +A/-R · api N.Ns` from `cost.total_premium_requests`,
  `cost.total_lines_added/removed`, `cost.total_api_duration_ms`) renders
  in the slot ccusage occupies for Claude payloads; session duration
  prefers `cost.total_duration_ms` over `transcript_path` mtime when
  available.
- `install.sh` — orchestrator that auto-detects supported CLIs on `$PATH`,
  with flags: `--target`, `--all`, `--dry-run`, `--uninstall`, `--quiet`,
  `--no-animation`. Honors `NO_COLOR` and `TUI_NO_ANIM`.
- `installers/` — per-tool installers for `claude-code`, `opencode`,
  `copilot-cli`, `pi`, `hermes`, plus shared `_lib.sh` (jq-based JSON
  editing, dry-run support) and `_tui.sh` (animated retro-terminal logo,
  box-drawing primitives, summary table).
- `bootstrap.sh` — `curl | bash` entry point. Clones to
  `~/.local/share/kinncj-statusline` and hands off to `install.sh`.
  Knobs: `STATUSLINE_REPO`, `STATUSLINE_REF`, `STATUSLINE_DIR`.
- `tests/installers/*.bats` — 30 bats tests against a sandbox `$HOME`
  covering every installer, the dispatcher, the bootstrap, and the TUI
  helpers.
- `.github/workflows/ci.yml` — CI with bats on Ubuntu + macOS,
  shellcheck on every shell file, and a statusline.sh fixture-render
  smoke job.
- Repo metadata: GPL-3.0-or-later license, CONTRIBUTING, CODE_OF_CONDUCT,
  AUTHORS, SECURITY.

### Fixed
- `json_set` in `installers/_lib.sh` no longer trips
  `"${empty_array[@]}"` unbound-variable errors under macOS's bash 3.2
  when called without `--arg` flags (uninstall paths).
- `installers/copilot-cli.sh` writes `statusLine` to
  `~/.copilot/config.json` (the file Copilot actually reads) instead of
  `~/.copilot/settings.json`, and persists `"experimental": true` so the
  feature gate is enabled without requiring `copilot --experimental` at
  launch. Cleans up the dead `statusLine`/`footer` keys older installer
  versions left in `settings.json`. Verified against Copilot CLI 1.0.46.

[Unreleased]: https://github.com/kinncj/statusline/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/kinncj/statusline/releases/tag/v0.1.0

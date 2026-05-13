# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2026-05-12

### Fixed
- Pi extension's handlers were registered with the wrong signature: Pi's
  `ExtensionHandler<E>` is `(event: E, ctx: ExtensionContext) => …` — ctx
  is the **second** argument. v0.2.0/0.2.1 wired handlers as
  `pi.on("session_start", refresh)` where `refresh(ctx)` actually received
  the event object as its first arg, leaving the real ctx unused. `ctx.ui`
  was therefore undefined and `setWidget` threw silently inside the
  try/catch — the extension loaded, handlers fired, no widget rendered.
  Fixed by wrapping handlers as `(event, ctx) => refresh(ctx)`.

### Added
- Opt-in debug log for the Pi extension. Set `PI_STATUSLINE_DEBUG=1`
  before launching `pi` and per-event records (module load, event firings,
  ctx shape, statusline.sh exit code, setWidget errors) are appended to
  `/tmp/pi-statusline-debug.log`. No-op when unset.
- `bootstrap.sh` now prints a version header on every run: installed
  version (tag + short SHA, or "not yet installed"), latest release tag
  on the remote, and latest commit on the tracked ref. After the
  clone/update it prints a one-line verdict (`✓ installed at vX.Y.Z`,
  `✓ already at vX.Y.Z — re-running install`, or
  `↑ updated: vA.B.C → vX.Y.Z`). The bootstrap already always pulled
  latest; this surfaces *what changed* so re-running `curl … | bash`
  is no longer opaque. Tag refs are now fetched alongside the branch
  so `git describe` can name the current commit when it lands on a tag.

## [0.2.1] - 2026-05-12

### Fixed
- Pi extension was installed but **never loaded**: Pi 0.73.1's discovery
  in `discoverExtensionsInDir` only matches files ending in `.ts`/`.js`,
  or a subdir containing `index.{ts,js}`, or a subdir with a
  `package.json` whose `pi.extensions[]` array lists the entry. Our
  v0.2.0 ship had only `statusline.mjs` (no manifest, wrong extension),
  so Pi silently skipped it. Added `extensions/pi/package.json` with
  `{"type":"module","pi":{"extensions":["statusline.mjs"]}}` so the
  manifest path resolves it. Installer copies the manifest alongside
  the existing `.mjs`. After reinstall, relaunch `pi` and the widget
  will render below the editor.

## [0.2.0] - 2026-05-12

### Added
- Pi (`@earendil-works/pi-coding-agent`, formerly `@mariozechner/pi-coding-agent`)
  is now a fully supported target instead of AGENTS.md-only. New
  `extensions/pi/statusline.mjs` is a native Pi `ExtensionFactory`
  (auto-discovered from `~/.pi/agent/extensions/`) that subscribes to
  `session_start`/`turn_end`/`tool_execution_end`/`agent_end`/`model_select`,
  synthesizes a Claude-shaped payload from `ctx.cwd` + `ctx.model`
  + `ctx.getContextUsage()`, execs the same `statusline.sh` every other
  host uses, and renders the result via
  `ctx.ui.setWidget(key, lines, {placement:"belowEditor"})`. Pi's native
  footer stays as-is; our widget sits under the editor so both lines
  coexist. No settings to edit — Pi auto-discovers the extension on
  next launch.
- `installers/pi.sh` rewritten: installs the extension package
  (`statusline.mjs` + a sibling `statusline.sh` so the extension's
  `import.meta.url`-relative lookup resolves locally) into
  `~/.pi/agent/extensions/kinncj-statusline/`, alongside AGENTS.md.

### Fixed
- `tests/installers/copilot-cli.bats` updated for the v0.1.0 config-file
  migration (statusLine now in `~/.copilot/config.json`, not
  `settings.json`). Adds coverage for the `//` header-comment strip
  path and the `settings.json` dead-key migration.

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

[Unreleased]: https://github.com/kinncj/statusline/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/kinncj/statusline/releases/tag/v0.2.2
[0.2.1]: https://github.com/kinncj/statusline/releases/tag/v0.2.1
[0.2.0]: https://github.com/kinncj/statusline/releases/tag/v0.2.0
[0.1.0]: https://github.com/kinncj/statusline/releases/tag/v0.1.0

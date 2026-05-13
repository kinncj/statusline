# AGENTS.md — kinncj statusline

This repo is a portable two-line statusline for AI CLIs (Claude Code, OpenCode, GitHub Copilot CLI) plus AGENTS.md / skill installers for tools that lack a scriptable statusline (Pi, Hermes).

If you are an AI agent working on this repo, read this file first — every host that supports AGENTS.md will load it automatically. The instructions below apply regardless of which CLI you are running under.

## What the statusline does

It reads JSON from stdin (the host's session info) and prints two lines:

```
dir: <dirname> | branch: <git-branch> | think:<effort>
context: <pct>% (<used>/<size>, <left> left) | <ccusage cost block> | 5h quota: ... | 7d quota: ...
```

Segments self-suppress when their data isn't present. Line 1 covers identity. Line 2 covers usage and budget.

## Repo layout

```
statusline.sh                    # the script itself — single source of truth
install.sh                       # orchestrator (detects tools, dispatches)
installers/
  _lib.sh                        # shared bash helpers (run, json_set, copy_statusline)
  claude-code.sh                 # wires ~/.claude/settings.json
  opencode.sh                    # wires ~/.config/opencode/opencode.json
  copilot-cli.sh                 # wires ~/.copilot/settings.json
  pi.sh                          # AGENTS.md only (no statusline hook)
  hermes.sh                      # AGENTS.md + skill (no statusline hook)
.claude/agents/                  # Claude Code project-scoped agents
.claude/skills/                  # Claude Code project-scoped skills
.opencode/agents/                # OpenCode project-scoped agents
tests/                           # mock-JSON inputs for testing the script
```

## Host support status (verified vs. aspirational)

Be honest in user-facing docs about which of these installers is wiring something that actually works:

| Tool         | Statusline hook support     | Notes |
|--------------|-----------------------------|-------|
| Claude Code  | ✓ shipped                   | `settings.json.statusLine = {type:"command", command, padding}` — official. |
| Copilot CLI  | ✓ shipped                   | Confirmed via github/copilot-cli changelog. Same shape as Claude Code, lives in `~/.copilot/settings.json` (user settings) — *not* `config.json` (internal state). Toggle visibility with `/statusline` inside Copilot. `statusLine.command` supports `~` and env vars. |
| OpenCode     | ⚠ not shipped               | Feature request open at anomalyco/opencode#8619. Our installer writes `.statusline` and `.experimental.statusline` keys speculatively so a future ship lands without a re-install. Today the runtime ignores them; the AGENTS.md drop is what carries weight. |
| Pi           | ✗ no command-style hook     | Pi customizes its footer through an npm extension system, **not** a shell-command hook like Claude Code. Users run `pi install npm:pi-powerline-footer` (or `pi-bar`, `pi-side-agents`, etc.). Our installer drops AGENTS.md and points users at the package. To wire `statusline.sh` natively into Pi we'd have to publish our own npm extension — not done. |
| Hermes       | ✗ no scriptable statusline  | Built-in TUI; only `display.tui_status_indicator` is tunable. AGENTS.md + skill only. |

If you change an installer to wire something new, verify against the upstream tool's released schema first and update this table.

## Host JSON schemas (what stdin looks like)

The statusline's `jq -r '… // empty'` filters mean missing fields silently render nothing — but the *shape* differs per host. When adding or debugging a segment, confirm the key path against the host you're targeting:

| Field                                  | Claude Code | OpenCode | Copilot CLI |
|----------------------------------------|-------------|----------|-------------|
| `.cwd`                                 | ✓           | ✓        | ✓           |
| `.model.display_name`                  | ✓           | ✓        | ✓ (likely)  |
| `.transcript_path`                     | ✓           | ✓        | ✓           |
| `.context_window.used_percentage`      | ✓           | ✓        | ✓           |
| `.context_window.context_window_size`  | ✓           | ✓        | ?           |
| `.rate_limits.{five_hour,seven_day}.*` | ✓ (Pro/Max) | —        | —           |
| `.thinking.enabled` / `.effort.level`  | ✓           | ?        | ?           |

Pi and Hermes do not pipe JSON to a statusline script — they have no such hook.

## Conventions when editing `statusline.sh`

These are not stylistic preferences — they are bug guardrails that bit us already:

1. **Always use `printf '%b' "..."` to emit the final line** — never `printf "$line"`. A literal `%` (e.g. in `ctx:12%`) crashes a format-string `printf`. The `%b` form treats the argument as data and still interprets `\033[…m` escapes.
2. **Don't strip ANSI escapes with `${var#$SEP}`** — `[` in escape codes is a glob char. Build raw (no-SEP) versions of each block instead, and add `${SEP}` only at join time.
3. **Every `jq` lookup gets `// empty`** so a missing field renders the segment empty, never the literal string `"null"`.
4. **Gate ccusage output**: skip it on `❌` or `Invalid` substrings — `ccusage` prints diagnostic errors to stdout when its input shape doesn't match.
5. **Color escalation for percentages**: green <50 → yellow 50-79 → red ≥80. Apply to context % and any future quota that has a budget.
6. **Label costs as `API-est:`** — they're API list-price estimates, not what Claude.ai subscribers actually pay. Don't drop the label.
7. **Segments self-suppress**: every block starts with `block=""` and only gets a value if its source data is present. Never emit a block whose value would be empty.

## Testing changes

### statusline.sh

Mock JSON inputs live in `tests/`. To run the script against one:

```bash
cat tests/fixture-claude-code.json | bash statusline.sh
# or strip ANSI for plain-text diff
cat tests/fixture-claude-code.json | bash statusline.sh | sed 's/\x1b\[[0-9;]*m//g'
```

### installer + TUI (bats)

Installer tests live in `tests/installers/` and use [bats-core](https://github.com/bats-core/bats-core). Each test runs against a fake `$HOME` so the user's real config is never touched.

```bash
# Install bats once (CachyOS: pacman -S bats, Debian: apt install bats, macOS: brew install bats-core)
tests/run.sh                  # all tests
tests/run.sh claude-code      # files matching a substring
bats tests/installers/*.bats  # bats directly
```

Conventions when adding tests:
- Always call `setup_fake_home` in `setup()` and `teardown_fake_home` in `teardown()`.
- Use `run_installer <name>` to drive a single installer; use `run_install <flags>` for the dispatcher.
- Assert filesystem state and `jq` queries against the resulting JSON — not on log strings, which change as the TUI evolves.

When ccusage is in play, it requires a real transcript file. For a hermetic test, stub it:

```bash
mkdir -p /tmp/sl-stub
cat > /tmp/sl-stub/npx <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
printf '%s' '🤖 Test Model | 💰 $1.00 session / $0.00 today / $5.00 block (3h left) | 🔥 $10/hr | 🧠 50,000 (5%)'
STUB
chmod +x /tmp/sl-stub/npx
PATH="/tmp/sl-stub:$PATH" bash statusline.sh < tests/fixture-claude-code.json
```

## Installing

```bash
./install.sh                     # interactive, all detected tools
./install.sh --all               # non-interactive
./install.sh --target opencode   # specific tool (repeatable)
./install.sh --dry-run           # show what would happen
./install.sh --uninstall         # remove wiring (statusline.sh in repo is untouched)
```

The installer is idempotent: running it twice just rewrites the same paths.

## When changing the install surface

If you add a new tool installer, do all of:

1. Drop `installers/<tool>.sh` (executable, sources `_lib.sh` which transitively sources `_tui.sh`).
2. Add `<tool>)` to `detect()` and `KNOWN_TOOLS` in `install.sh`.
3. Update both tables above — host support status AND stdin schema (or note it has no statusline hook).
4. Update `README.md` with the user-facing description.
5. Add a `tests/installers/<tool>.bats` covering install + uninstall + jq assertions against the resulting JSON.
6. Test with `--dry-run --target <tool>` and run `tests/run.sh`.

## TUI helpers

`installers/_tui.sh` provides the animated logo, box drawing, and section banners used by `install.sh`. Anything user-facing that produces formatted output goes through it.

Knobs the helpers honor:
- `NO_COLOR=1` — disables all color escapes (per https://no-color.org).
- `TUI_NO_ANIM=1` — skips animations, prints final frames instantly. `install.sh --no-animation` sets this.
- Non-TTY stdout — both color and animation auto-disable, so piping the installer into a log file stays clean.

Per-installer scripts should call `ok` / `warn` / `err` / `info` (mapped to the indented variants from `_tui.sh`) so output lines up inside the section box.

## Tone for end-user-facing strings

Installer output is short and direct. `ok` / `warn` / `err` / `info` helpers in `_lib.sh` cover the four levels. No emoji in installer messages — they're for the statusline itself, where they're decorative and meaningful (💰 cost, 🔥 burn, 🤖 model).

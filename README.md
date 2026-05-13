# kinncj statusline

```
 ██╗  ██╗██╗███╗   ██╗███╗   ██╗ ██████╗     ██╗
 ██║ ██╔╝██║████╗  ██║████╗  ██║██╔════╝     ██║
 █████╔╝ ██║██╔██╗ ██║██╔██╗ ██║██║          ██║
 ██╔═██╗ ██║██║╚██╗██║██║╚██╗██║██║     ██   ██║
 ██║  ██╗██║██║ ╚████║██║ ╚████║╚██████╗╚█████╔╝
 ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═══╝ ╚═════╝ ╚════╝
        s · t · a · t · u · s · l · i · n · e
```

[![CI](https://github.com/kinncj/statusline/actions/workflows/ci.yml/badge.svg)](https://github.com/kinncj/statusline/actions/workflows/ci.yml)

A portable, two-line statusline for AI CLIs. Shows model, context usage with tokens remaining, API-estimated costs, and Claude.ai rate-limit quotas with reset times.

```
dir: frontend | branch: main | think:xhigh
context: 6% (56K/1.0M, 943K left) | 🤖 Opus 4.7 (1M context) | 💰 API-est: $1.39 session / $0.00 today / $5.61 block (3h 41m left) | 🔥 $11.79/hr | 5h quota: 7% (resets 3h41m) | 7d quota: 12% (resets 5d0h)
```

## Install

### Quick — `curl | bash`

```bash
curl -fsSL https://raw.githubusercontent.com/kinncj/statusline/main/bootstrap.sh | bash
```

The bootstrap clones the repo into `~/.local/share/kinncj-statusline` and runs the installer for every supported CLI it finds on `$PATH`. To pass flags through to the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/kinncj/statusline/main/bootstrap.sh | bash -s -- --dry-run
curl -fsSL https://raw.githubusercontent.com/kinncj/statusline/main/bootstrap.sh | bash -s -- --target claude-code
curl -fsSL https://raw.githubusercontent.com/kinncj/statusline/main/bootstrap.sh | bash -s -- --uninstall
```

Override defaults via env: `STATUSLINE_REPO=owner/fork STATUSLINE_REF=v1.2.3 STATUSLINE_DIR=~/elsewhere curl … | bash`.

### Manual — clone + run

```bash
git clone https://github.com/kinncj/statusline ~/Development/kinncj/statusline
cd ~/Development/kinncj/statusline
./install.sh                     # auto-detect all supported CLIs on $PATH
./install.sh --target opencode   # one specific tool, repeatable
./install.sh --dry-run           # preview without changing anything
./install.sh --uninstall         # remove statusline wiring
./install.sh --no-animation      # skip the animated intro (also: NO_COLOR=1, TUI_NO_ANIM=1)
./install.sh --quiet             # suppress the logo entirely
```

The installer renders a boxed, animated TUI by default. Animations auto-disable when stdout isn't a TTY (CI, pipes), and color follows `NO_COLOR`.

## Supported targets

| Tool                       | Statusline | AGENTS.md | Config path                              |
|----------------------------|:----------:|:---------:|------------------------------------------|
| **Claude Code**            | ✓          | ✓         | `~/.claude/settings.json`                |
| **GitHub Copilot CLI**     | ✓          | ✓         | `~/.copilot/settings.json`               |
| **OpenCode**               | ⚠ pending  | ✓         | `~/.config/opencode/opencode.json` (FR: anomalyco/opencode#8619) |
| **Pi (pi.dev)**            | —          | ✓         | `~/.pi/agent/` — Pi uses npm extensions, not a script hook |
| **Hermes (nousresearch)**  | —          | ✓ + skill | `~/.hermes/` (full TUI, no script hook)  |

Pi and Hermes don't expose a script-driven statusline:
- **Pi** customizes its footer through npm extensions (`pi install npm:pi-powerline-footer`, `pi-bar`, `pi-side-agents`). Our installer drops AGENTS.md and points you at those.
- **Hermes** ships a fixed built-in TUI with skin-level theming only. We install AGENTS.md + the `statusline-edit` skill so the repo's instructions travel with you.

**OpenCode** doesn't ship the hook yet — the installer writes the two proposed key shapes speculatively so it'll work as soon as anomalyco/opencode#8619 ships.

## What's in line 2

- `context: N%` of the context window, with `(used/total, remaining)` in human units
- `🤖` model name (from ccusage)
- `💰 API-est:` session / today / billing-block costs — **API list-price estimates**, not what Claude.ai Pro/Max subscribers actually pay
- `🔥 $X/hr` burn rate
- `5h quota` / `7d quota` percentage and reset countdown (Claude.ai subscriber data, when the host provides it)

## Dependencies

- `bash`, `jq`, `awk`, `sed`, `date`, `stat`, `git`
- `npx` (for ccusage — optional; the cost block is skipped if unavailable)

## Hacking on it

Read `AGENTS.md` — it has the conventions, the bash gotchas, the host JSON schemas, and the test recipe. Mock fixtures live in `tests/`.

If you're an AI agent working in this repo (Claude Code, OpenCode, etc.), `AGENTS.md` is loaded automatically. The `.claude/` and `.opencode/` directories also contain in-repo agent definitions for testing and safe-edit workflows.

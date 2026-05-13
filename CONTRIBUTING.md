# Contributing

Thanks for considering a contribution. This project stays small on purpose;
the bar is "useful and verifiable" rather than "feature complete."

## Ground rules

- **Read `AGENTS.md` first.** It documents the bash gotchas, per-host JSON
  schemas, color-escalation rules, and the conventions that make
  `statusline.sh` not crash on weird inputs. Most surprising bugs in this
  repo's history are listed there as guardrails.
- **Keep it portable.** macOS ships bash 3.2; we run on it. Avoid
  bash-4-only syntax (`declare -A`, `${var,,}`, etc.) unless you guard for
  it. Avoid GNU-only flags on `sed`, `date`, `stat`.
- **Every segment self-suppresses.** A missing input field renders empty,
  never the literal `null`. New `jq` lookups end in `// empty`.
- **Don't add dependencies casually.** `bash`, `jq`, `awk`, `sed`, `date`,
  `stat`, `git`, and optionally `npx` are the baseline. Anything else
  needs a strong reason.

## Workflow

```bash
git clone https://github.com/kinncj/statusline
cd statusline
./tests/run.sh                # bats suite (install bats first)
shellcheck install.sh bootstrap.sh installers/*.sh statusline.sh tests/run.sh
```

Open a PR with a tight description of *what* changed and *why*. CI runs
bats on Ubuntu + macOS, shellcheck, and a fixture-render smoke test.

## Adding a new host

If you're wiring up a new AI CLI, do all of these:

1. Drop `installers/<tool>.sh` (executable, sources `_lib.sh`).
2. Add `<tool>)` to `detect()` and `KNOWN_TOOLS` in `install.sh`.
3. Update the host-support and stdin-schema tables in `AGENTS.md`.
4. Add a user-facing line to `README.md`.
5. Add `tests/installers/<tool>.bats` with install + uninstall + jq
   assertions on the resulting JSON.
6. Run `--dry-run --target <tool>` and `tests/run.sh`.

## Reporting bugs

Open an issue with:
- The host (Claude Code / OpenCode / Copilot CLI / Pi / Hermes) and its
  version.
- The output of `bash statusline.sh < <(your-fixture.json)` if reproducible.
- What you expected vs. what you saw.

Security-relevant reports: see [`SECURITY.md`](SECURITY.md).

# Security Policy

This is a small, open-source shell project. The realistic threat surface is
narrow and there are no servers, secrets, or user data sitting behind any of
this code. Default to open reporting; reserve the private channel for the
rare cases where it actually matters.

## Supported versions

Only the latest tagged release on `main` receives fixes. Older versions can
be patched on request — open an issue.

## Reporting

### Default: open a public issue

For almost everything, **just file a regular GitHub issue**:
<https://github.com/kinncj/statusline/issues/new>

This is true open source — community review beats secrecy for problems
like:

- shell quoting or injection bugs in `statusline.sh` / installers,
- path-traversal or surprise overwrites in `install.sh` / `bootstrap.sh`,
- the curl-bash flow doing something unexpected on a given platform,
- shellcheck findings the CI didn't catch.

A reproducible fixture or minimal command line is worth more than a
threat-model paragraph.

### Private path: when public disclosure is actually risky

For the genuinely sensitive cases — credible active-exploitation reports,
or a finding where publishing the repro before a fix would put real users
at risk — use one of:

1. **GitHub Private Vulnerability Reporting**:
   <https://github.com/kinncj/statusline/security/advisories/new>
   (Repo → Security tab → *Report a vulnerability*.) This is the modern,
   tracked path and gives us a private space to coordinate.
2. **Email**: **kinncj@protonmail.com** with `[statusline-sec]` in the
   subject. Expect an initial response within seven days.

If you're not sure which lane to use, lean public. The bar for going
private is "shipping a fix before disclosure would meaningfully reduce
harm" — most shell-script bugs don't meet it.

## Credit

Reporters are credited in `CHANGELOG.md` for the fixing release unless
they ask to stay anonymous.

## Scope

In-scope:

- shell injection through values rendered into the statusline,
- path traversal / arbitrary writes via the installers,
- the `bootstrap.sh` supply-chain surface (hardening suggestions —
  checksum pinning, signed releases — welcome).

Out of scope:

- vulnerabilities in third-party tools we shell out to (jq, git,
  ccusage, etc.) — please report those to their upstreams,
- bugs that require attacker-controlled write access to the user's
  `~/.claude/` (etc.) before the exploit chain starts.

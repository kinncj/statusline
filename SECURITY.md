# Security Policy

## Supported versions

This project tracks the `main` branch. Only the latest tagged release
receives fixes. If you need security backports to an older version, open
an issue and we can discuss.

## Reporting a vulnerability

Please **do not open a public GitHub issue** for security reports.

Email **kinncj@protonmail.com** with:

- A description of the issue and its impact.
- Steps to reproduce (a minimal failing fixture is ideal — see
  `tests/fixture-*.json`).
- Any suggested fix or mitigation, if you have one.

You can expect an initial response within seven days. If the issue is
confirmed, we'll work on a fix on a private branch, coordinate a disclosure
window with you, and credit you in the changelog unless you'd rather stay
anonymous.

## Scope

This is a small shell project; the realistic threat surface is:

- **Shell injection** through values rendered into the statusline
  (`statusline.sh` already uses `printf '%b'` and quotes inputs to avoid
  format-string crashes — anything that bypasses this is in-scope).
- **Path traversal or arbitrary writes** through the installers
  (`install.sh`, `bootstrap.sh`, `installers/*.sh`).
- **Privilege escalation** via the bootstrap's `curl | bash` flow — the
  remote source is GitHub over HTTPS and the bootstrap doesn't run with
  sudo, but suggestions to harden it (checksum pinning, signed releases)
  are welcome.

Out of scope: vulnerabilities in third-party tools we shell out to (jq,
git, ccusage, etc.) — please report those upstream.

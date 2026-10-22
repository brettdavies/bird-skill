# Security Policy

## Reporting a Vulnerability

Report every vulnerability privately to the repository that ships the binary, through
[`brettdavies/bird`](https://github.com/brettdavies/bird)'s private vulnerability reporting, rather than a public issue:

[Open a private security advisory on `brettdavies/bird`](https://github.com/brettdavies/bird/security/advisories/new)

That includes a vulnerability in this skill bundle (for example, a script in `bin/` or `scripts/` that could run
unintended commands on a user's machine, or a template under `templates/` that leads an agent to expose a credential).
Prefix the advisory's title with `[skill]` so it routes to the bundle. This repository takes no reports of its own.

## Disclosure Window

We aim to acknowledge reports within 5 business days and to publish a fix or mitigation within **90 days** of the
initial report. Coordinated disclosure is preferred; we will work with reporters to align on a public-disclosure date
that protects users while crediting the finder.

## Scope

A `[skill]` report covers:

- Shell scripts under `bin/` and `scripts/`, which ride along on every `bird skill install <host>`.
- Templates under `templates/` and the guidance in `SKILL.md` and `references/`, where it could lead an agent to leak a
  credential or run a write without confirmation.
- Governance files (`CODEOWNERS`, CI workflows) where misconfiguration could allow unreviewed code to ship.

A vulnerability in `bird` itself goes to the same place, without the prefix. Best-practice debates about the skill's
guidance are not vulnerabilities; open a regular issue on bird or a PR here for those.

## Supported Versions

Only the latest tagged release receives security fixes. Older tags are immutable historical records.

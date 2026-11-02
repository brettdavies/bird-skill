# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-06-04

### Added

- Initial bird agent-skill bundle: `SKILL.md` plus `references/`, `templates/`, `scripts/`, `evals/`. by @brettdavies in [#3](https://github.com/brettdavies/bird-skill/pull/3)
- `scripts/write-op-gate.sh` for bird write verbs (distinct from xurl-rs's `dry-run-gate.sh` because bird's envelope shape and BSD-sysexits exit codes differ).
- `eval-01-doctor-and-cached-search.md` end-to-end eval covering discovery, cached search replay, and forced escalation on an OAuth-scope question the bundle deliberately does not own.

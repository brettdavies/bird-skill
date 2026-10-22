# Contributing to `bird-skill`

Thanks for your interest. This repo is the agent-facing skill bundle that teaches Claude Code, Codex, Cursor, Factory,
Kiro, and OpenCode how to drive [`bird`](https://github.com/brettdavies/bird), the X API CLI with a local entity store.

The core rules are below; the producer-side workflow (repository shape, the test loop, the evals) lives in
[`AGENTS.md`](AGENTS.md) and the branch and release model in [`RELEASES.md`](RELEASES.md).

## Issues

This repository's issue tracker is disabled. File issues (bugs in `bird` itself, bugs in this skill bundle such as stale
references, broken links, or wrong invocations, and proposals for new templates, references, or `getting-started` flows)
against the upstream CLI:

➡️ **[`brettdavies/bird` › New issue](https://github.com/brettdavies/bird/issues/new/choose)**

If the issue is specifically about the skill bundle, prefix the title with `[skill]` so it routes to the right place.

## Pull requests

PRs against this repo are welcome: branch from `dev` and follow the workflow below.

## Workflow

- **Branch from `dev`.** `feat/*` for additions, `fix/*` for bug fixes, `chore/*` for tooling, `docs/*` for repo-level
  documentation only. Engineering docs under `docs/plans/`, `docs/solutions/`, `docs/brainstorms/`, `docs/reviews/` are
  blocked from `main` by `guard-main-docs`.
- **PR to `dev`.** Squash merge. The PR title becomes the commit title; the PR body becomes the commit message, and its
  `## Changelog` section becomes the release notes.
- **Conventional Commits.** `type(scope): description`. Prefer `feat` / `fix` over `chore` for anything user-observable,
  since `cliff.toml` drops `chore`, `style`, `test`, `ci`, and `build` from the changelog.
- **Signed commits required** on `main` and `dev` (ruleset-enforced).
- **No AI attribution** in commit messages or PR bodies.

## House rules

- **Pin third-party Actions by SHA**, never by mutable tag. A trailing comment names the version.
- **ShellCheck-clean** (`--severity=style`) for `bin/`, `scripts/`, `tests/`, and `fixtures/bin/`.
- **markdownlint-clean** for every `.md` file. The config is `.markdownlint-cli2.yaml`.
- **Every script change keeps `bash tests/run.sh` green**, and a fix to a script adds the test that fails without it. CI
  runs the tests against the stub `bird` in `fixtures/bin/`, so no test reaches the X API.
- **Vendored files are copies.** `scripts/generate-changelog.py`, `scripts/sync-dev-after-release.sh`,
  `scripts/release/`, `cliff.toml`, `tests/core-env-guard.sh`, and `.github/pull_request_template.md` come from the
  `github-repo-setup` skill or dotfiles; fix them at the source and re-vendor, never in place.

## Security

Report a vulnerability privately, not as an issue: see [`SECURITY.md`](SECURITY.md).

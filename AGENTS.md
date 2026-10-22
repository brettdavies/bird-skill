# AGENTS.md for bird-skill

Producer-side instructions for agents (Claude Code, Codex, Cursor, OpenCode) working **on** this skill bundle.
Consumer-side instructions (how an agent should *use* the bundle once installed) live in `SKILL.md`.

## Documented contract

The bundle documents the `bird` release it ships beside: the latest GitHub release of
[`brettdavies/bird`](https://github.com/brettdavies/bird/releases), installed by `brew install brettdavies/tap/bird`.
Consumers install from the head of `main` with the bundle's own `VERSION`; nothing pins the bundle to a binary version
on either side.

The docs state only what the binary cannot tell an agent itself: which stream a document lands on, exit codes, envelope
shapes, cache semantics, the scripts' behavior, and the gotchas. For flag lists, help text, and schema names they point
at `bird --help`, `bird <cmd> --help`, `bird --examples`, and `bird schema --list`, so those facts need no per-release
edit.

No harness runs the documented invocations against a real `bird` binary. `tests/run.sh` covers the bundle's own scripts
against the stub in `fixtures/`; a claim about what `bird` emits is checked by running it.

## Repository shape

| Path                 | Role                                                                                                                                                                                 |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `SKILL.md`           | Consumer-facing entry point. Loaded by the agent when the skill activates.                                                                                                           |
| `references/`        | Reference material an agent reads on demand. One topic per file.                                                                                                                     |
| `templates/`         | Task recipes an agent follows (cached search, watchlist monitoring).                                                                                                                 |
| `getting-started.md` | Human-oriented quickstart that complements `SKILL.md`.                                                                                                                               |
| `bin/`               | `check-update`, the consumer-side update check `SKILL.md` runs first.                                                                                                                |
| `scripts/`           | The consumer-side `write-op-gate.sh` plus producer-side release tooling (`generate-changelog.py`, `sync-dev-after-release.sh`).                                                      |
| `scripts/release/`   | Vendored release gates (`drift.sh`, `guarded-paths.sh`, `_lib.sh`). Verbatim copies from the `github-repo-setup` skill; never edited in place.                                       |
| `tests/`             | Producer-side: `run.sh` (fixture-driven tests of `write-op-gate.sh` and `check-update`, run in CI); `core-env-guard.sh` (a verbatim template copy that CI runs over the test files). |
| `fixtures/`          | The stub `bird` that `tests/run.sh` puts on `PATH`; it models the real streams (success on stdout, error envelope on stderr with the exit code) and the non-TTY write refusal.       |
| `evals/`             | Self-contained eval prompts dispatched against a fresh agent session. Producer.                                                                                                      |
| `.github/`           | Workflows, rulesets, PR template, Dependabot, `CODEOWNERS`.                                                                                                                          |

The whole repository is the install: `bird skill install <host>` clones it, so producer-side files ride along. Nothing
in `SKILL.md` points an agent at them.

## Branch model

- `dev`: forever branch. Daily work lands here via `feat/*` / `fix/*` / `chore/*` / `docs/*` PRs.
- `main`: forever branch. Receives only `release/*` PRs cut from `origin/main` with `dev`'s tree overlaid on top and the
  guarded set stripped (`scripts/release/guarded-paths.sh`). Engineering docs under `docs/plans/`, `docs/solutions/`,
  `docs/brainstorms/`, `docs/reviews/` are blocked on `main` by `guard-main-docs`.
- `release/*`: ephemeral. Auto-deleted on merge.

`VERSION` and `CHANGELOG.md` are release bookkeeping: the release branch writes them (`scripts/generate-changelog.py`
builds the changelog from merged PR bodies) and `scripts/sync-dev-after-release.sh` brings them back to `dev`. Never
edit `CHANGELOG.md` by hand. See [`RELEASES.md`](RELEASES.md) for the full release workflow.

## CI

| Workflow                    | Triggers                         | What it checks                                                                                                                  |
| --------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `ci.yml`                    | every PR; push to `main` / `dev` | `markdownlint`; `shellcheck` on `bin/`, `scripts/`, `tests/`, `fixtures/bin/`; `scripts-tests` (core-env guard, `tests/run.sh`) |
| `guard-main-docs.yml`       | PR to `main`                     | Blocks engineering docs from reaching `main`                                                                                    |
| `guard-release-branch.yml`  | PR to `main`                     | Rejects any head branch not under `release/`                                                                                    |
| `guard-main-provenance.yml` | PR to `main`                     | Requires every commit to carry a `(#N)` squash-merge reference                                                                  |

## Refreshing the bundle against a new `bird`

1. Read the release's notes and `bird --help`, `bird <cmd> --help`, and `bird schema --list` from the new binary for
   added, renamed, or removed commands, flags, env vars, exit codes, and envelope keys.
2. Run every invocation a changed passage documents against the new binary, and record what it prints. Prefer reads the
   local store answers (`--cache-only`), `--dry-run` for writes, and `bird doctor`, `bird schema`, and
   `bird usage --local`, which make no billed call. Never run a live write to check a doc.
3. Fix each passage the binary contradicts. When a script's contract moves (the gate's flags, an envelope key it reads),
   change the script, its stub in `fixtures/bin/bird`, and `tests/run.sh` together.
4. Run `bash tests/run.sh`, `bash tests/core-env-guard.sh`, shellcheck, and markdownlint with CI's globs, then re-run
   the evals in `evals/` that touch the changed surface.

## Issues

This repository has its issue tracker **disabled** (`has_issues: false`). File issues, and report vulnerabilities
privately (see [`SECURITY.md`](SECURITY.md)), against the upstream CLI:

➡️ **<https://github.com/brettdavies/bird/issues/new/choose>**

When an agent files an issue about this skill bundle specifically, **prefix the title with `[skill]`** so the upstream
maintainer can triage it.

## House rules

- **No AI attribution in commits or PR bodies.** No `Co-Authored-By: Claude`, no `Generated with` trailers.
- **Signed commits required** on `main` and `dev` (ruleset-enforced).
- **Squash merges only.** PR title becomes the commit title; PR body becomes the commit message.
- **Conventional Commits**: `type(scope): description`. Prefer `feat` / `fix` over `chore` for anything user-observable.
- **Pin third-party actions by SHA**, never mutable tag. Trailing comment names the version.
- **No live X API calls from tests.** The API is billed per object read; tests use the stub.

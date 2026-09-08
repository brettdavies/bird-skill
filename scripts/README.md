# scripts/

Consumer-side helper scripts that ride along on every `bird skill install <host>`. They land next to the bundled
`SKILL.md` at `~/.claude/skills/bird/scripts/` (and the host-equivalent path on Codex / Cursor / Factory / Kiro /
OpenCode) once installed.

The scripts are `#!/usr/bin/env bash`, shellcheck-clean, and invokable from any working directory.

| Script             | Purpose                                                                                                      | Exit codes                                                                                                    |
| ------------------ | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| `write-op-gate.sh` | Enforce `--dry-run` → confirm → live for any **bird** write verb. Distinct from xurl-rs's `dry-run-gate.sh`. | 0 live OK · 1 dry-run reject · 2 usage / forbidden flags · 3 non-TTY w/o `--yes` · 4 declined · * passthrough |

## `write-op-gate.sh`

```bash
~/.claude/skills/bird/scripts/write-op-gate.sh [--yes] -- bird <write-verb> [args...]
```

What it does:

1. Runs the verb with `--dry-run --output json --quiet`.
2. If the dry-run envelope is non-zero, surfaces `kind` + `exit_code` + `error` and exits 1.
3. On a TTY, prompts `[y/N]`. Off-TTY, requires `--yes` or refuses with exit 3.
4. `exec`s the verb again with `--output json` (no `--dry-run`) so the live response envelope lands on stdout.

Do NOT pass `--dry-run`, `--force`, `--yes`, `--output`, `--json`, or `--jsonl` in `<args>` — the gate controls them.
The script refuses if any appear.

Examples:

```bash
# Interactive (TTY) — gate prompts before going live.
~/.claude/skills/bird/scripts/write-op-gate.sh -- bird tweet "Shipping today."

# Headless — caller has already confirmed scope with the user.
RESP=$(~/.claude/skills/bird/scripts/write-op-gate.sh --yes -- \
  bird reply 1234567890 "Congrats!")
ID=$(printf '%s' "$RESP" | jaq -r '.data.id')   # jaq or jq

# DM (always treat as destructive — confirm in interactive mode).
~/.claude/skills/bird/scripts/write-op-gate.sh -- bird dm jack "ping"
```

## When NOT to use `write-op-gate.sh`

- **Read ops** — `bird me`, `bird bookmarks`, `bird search`, `bird thread`, `bird profile`, `bird get`, `bird usage`,
  `bird cache stats`, `bird doctor`, `bird watchlist list|fetch`. These don't mutate state and don't accept `--dry-run`.
  Run them directly.
- **`bird skill install` / `update`** — these are local-only ops (clone a git repo into a host's skills dir). They
  already gate on `<host>` or `--all` with exit 2 `missing-host`; `--dry-run` prints the planned clone command. The
  write-op gate doesn't add value here.

## Why bird ships its own gate

The xurl-rs skill ships a similar `dry-run-gate.sh`. They cover overlapping territory but differ where it matters:

- **Envelope shape**: bird's error envelope keys are `error` / `kind` / `exit_code` (with optional `command` / `status`
  / `reason`). xurl-rs's envelope keys are `status` / `would_succeed` / `exit_code`. The dry-run preflight check is
  different per binary.
- **Exit-code split**: bird uses BSD sysexits (0/1/2/77/78). xurl-rs has its own scheme.
- **Default `--force` semantics**: bird treats `--force` as "skip confirmation"; the gate inserts the confirmation
  before reaching `--force`, then doesn't pass it through (the live call is already gated).

If you have xurl-rs installed, its `dry-run-gate.sh` should be used for `xr` write verbs. Use bird's `write-op-gate.sh`
for `bird` write verbs. They are not interchangeable.

## Local invocation (from the bundle directory)

When the bundle is checked out for development (not installed via `bird skill install`), invoke from the bundle root:

```bash
./scripts/write-op-gate.sh --yes -- bird tweet "..."
```

## Maintainer-side release tooling

Everything else under `scripts/` is release-flow tooling for this repo's maintainers, vendored from the
`github-repo-setup` skill and not part of the consumer contract. It rides along on install because the bundle is the
whole repo, but nothing in `SKILL.md` points an agent at it.

| Path                        | Role                                                                           |
| --------------------------- | ------------------------------------------------------------------------------ |
| `release/drift.sh`          | Branch drift gate: what `main` holds that `dev` never received.                |
| `release/guarded-paths.sh`  | Emits the `grep -E` pattern for every path `guard-main-docs` blocks on `main`. |
| `release/_lib.sh`           | Shared helpers sourced by the release scripts.                                 |
| `generate-changelog.py`     | Builds the `CHANGELOG.md` section from merged PR bodies (`--from-dev-prs`).    |
| `sync-dev-after-release.sh` | Backports `VERSION` and `CHANGELOG.md` from `main` to `dev` via a PR.          |

The runbook is [`RELEASES.md`](../RELEASES.md).

## Requirements

- `bash` — `#!/usr/bin/env bash`, uses `[[ ]]` regex matching.
- [`jaq`](https://github.com/01mf02/jaq) (preferred) OR `jq`. The script picks `jaq` when both are installed.
- `bird` 0.x or higher on `$PATH`.

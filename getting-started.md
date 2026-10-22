# Getting started with the `bird` skill

This is the human-facing quickstart. The agent-facing entry point is [`SKILL.md`](SKILL.md); the producer-side notes for
working on this bundle are in [`AGENTS.md`](AGENTS.md).

## What this bundle is

A consumer-side skill bundle for [`bird`](https://github.com/brettdavies/bird), the X API CLI with a local entity store,
watchlists, thread reconstruction, and a usage ledger. It teaches your coding agent which bird command answers a task,
how to keep repeated reads off the billed API with bird's cache modes, and how to put every write behind a dry run and
your confirmation, because bird runs against your production X account.

When the bundle is installed at `~/.claude/skills/bird/` (or the equivalent path on Codex / Cursor / Factory / Kiro /
OpenCode), the agent reads the description in `SKILL.md` and pulls the rest of the files in on demand.

## Install

Install `bird` first:

```bash
brew install brettdavies/tap/bird
bird --version
```

The `bird` binary installs this bundle itself, by a shallow `git clone` of this repository:

```bash
bird skill install claude_code             # install for Claude Code
bird skill install codex                   # install for Codex
bird skill install --all                   # install across every supported host
bird skill install claude_code --dry-run   # print the planned clone without running it
```

Hosts and install paths:

| Host          | Install path                     |
| ------------- | -------------------------------- |
| `claude_code` | `~/.claude/skills/bird`          |
| `codex`       | `~/.codex/skills/bird`           |
| `cursor`      | `~/.cursor/skills/bird`          |
| `factory`     | `~/.factory/skills/bird`         |
| `kiro`        | `~/.kiro/skills/bird`            |
| `opencode`    | `~/.config/opencode/skills/bird` |

`install` refuses a destination that already exists. Update in place:

```bash
bird skill update claude_code              # remove the install dir and clone fresh
bird skill update --all                    # every supported host
```

Uninstall:

```bash
rm -rf ~/.claude/skills/bird               # or the equivalent host path
```

Once a session starts, the agent runs `bin/check-update` and offers `bird skill update <host>` when a newer bundle is on
`main` ([`references/update-check.md`](references/update-check.md)).

## First session

The skill activates the next time you ask your agent something X-flavored. Try:

> Is my X tooling ready to use? If not, what's broken?

The agent routes through `SKILL.md` to `bird doctor --output json` and reads its report rather than guessing. Then:

> Search recent posts about `rustlang` with links, top 5 by likes, then show me the same results again without spending
> API credits.

The agent opens [`templates/cached-search.md`](templates/cached-search.md), runs the search once, and replays it from
bird's local store with `--cache-only`, which never sends a request.

To explore by hand:

```bash
bird --help                       # full surface
bird --examples                   # curated invocation gallery
bird <cmd> --help                 # per-command flags
bird schema --list --output json  # every output shape bird documents
bird doctor --output json         # environment, auth, and store health
bird usage --local                # bird's local cost ledger, no API call
```

## Writes

Every write (a new post, a reply, a like, a follow, a DM, a delete, …) hits your real account. The bundle ships
[`scripts/write-op-gate.sh`](scripts/README.md), which runs the write with `--dry-run` first, shows you the would-be
request, asks for confirmation on a terminal (or requires `--yes` when there is none), and only then sends it. bird
itself refuses a write from a caller without a terminal unless it carries `--force` or `--yes`, so nothing hangs waiting
for input.

## What's in this bundle

```text
bird-skill/
├── SKILL.md                     # consumer entry point (the agent reads this)
├── getting-started.md           # this file
├── AGENTS.md                    # producer-side notes (for editors of this bundle)
├── bin/
│   └── check-update             # compares the installed VERSION with main
├── references/
│   ├── agent-flags.md           # global flags, env vars, output-format choice
│   ├── cache-modes.md           # --refresh / --no-cache / --cache-only, TTLs, offline replay
│   ├── error-envelope.md        # error shape, exit codes, symptom-to-fix map
│   ├── escalation.md            # when stuck: lookup order and iron rules
│   ├── schemas.md               # bird schema documents and validation recipes
│   ├── skill-install.md         # bird skill install / update mechanics
│   ├── update-check.md          # bin/check-update's prompt and state files
│   ├── usage-and-cost.md        # bird usage, the local ledger vs the API's view
│   └── xr-bridge.md             # what bird leaves to xr and the xurl-rs skill
├── templates/
│   ├── cached-search.md         # ranked search with cache-mode selection
│   └── watchlist-monitor.md     # track accounts, cron-friendly check
└── scripts/
    ├── write-op-gate.sh         # --dry-run → confirm → live, for every bird write
    └── README.md                # the gate's contract
```

## Companion skills

This bundle is about **using** bird. Two companions cover what it leaves out:

- [`xurl-rs`](https://github.com/brettdavies/xurl-rs-skill): the `xr` CLI's full surface, including OAuth flows, media
  upload, and streaming. Install it with `xr skill install <host>`.
- `x-api`: X API endpoint shapes, OAuth2 scopes per operation, billing, and rate-limit tables.

Without the `x-api` skill, fall through to <https://docs.x.com/> (append `.md` to a docs URL for agent-friendly
markdown; [`references/escalation.md`](references/escalation.md) has the lookup order).

## Reporting issues

File bugs in bird itself and in this bundle (stale references, broken links, wrong invocations) at the bird repository:

➡️ **<https://github.com/brettdavies/bird/issues/new/choose>**

When the issue is about this bundle specifically, **prefix the title with `[skill]`** so it can be triaged correctly.

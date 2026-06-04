---
name: bird
description: Drive the `bird` CLI for the X (Twitter) API — entity-store-backed reads (`--refresh` / `--no-cache` / `--cache-only`), watchlist monitoring, thread reconstruction, API usage and cost ledger, `bird doctor` self-diagnostics, JSON Schema output documents, search with sort/min-likes/pages, and the bird-specific write-op confirmation flow (`--dry-run`, `--force`, exit 2 `requires-confirmation`). Use when the user wants to read bookmarks or a profile, search recent tweets with ranking, rebuild a conversation thread, manage a watchlist, check API cost, inspect cache, run diagnostics, install the skill bundle, or any task where bird's local cache or structured error envelope matters. For OAuth flows, raw write-op transport, or full xr surface, route to the companion `xurl-rs` skill; for X API v2 endpoint, scope, and billing reference, route to the companion `x-api` skill. Triggers on "bird command", "bird search", "bird watchlist", "bird bookmarks", "bird thread", "bird doctor", "bird cache", "bird usage", "X API cost", "Twitter cache", "X watchlist", "thread reconstruction", "bird schema".
---

# bird

`bird` is a Rust CLI that wraps the X (Twitter) v2 API with capabilities `xurl` does not have: a SQLite **entity store**
with per-endpoint TTL, **watchlist** monitoring, **thread reconstruction**, **API usage** with local cost ledger,
**structured error envelopes** with split exit codes (`0` / `1` / `2` / `77` / `78`), **JSON Schema** documents for
every output shape, **search ergonomics** (`--sort likes --min-likes --pages`), and `bird doctor` self-diagnostics
covering xurl status, auth state, command availability, and store health.

bird does **not** implement HTTP or OAuth itself. Every API call shells out to `xr` (xurl-rs) or `xurl` (Go fallback) at
runtime. Discovery order: `BIRD_XURL_PATH` env → `xr` on `$PATH` → `xurl` on `$PATH`. Minimum xurl version: 1.0.3.

## Sibling skills — install if you don't have them

Two companion skills cover ground this skill deliberately does NOT duplicate. Reach for them when the task crosses their
line.

| Skill                                                     | Owns                                                                                                                                                                                                                                                  | Install                        |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ |
| [`xurl-rs`](https://github.com/brettdavies/xurl-rs-skill) | Full `xr` surface — OAuth2 PKCE / OAuth1 / Bearer flows, multi-app token store at `~/.xurl`, chunked media upload, streaming, the `dry-run-gate.sh` and `paginate.sh` helpers, the typed `ok` / `dry_run` / `error` output envelope, X API essentials | `xr skill install claude_code` |
| [`x-api`](https://github.com/brettdavies/x-api-skill)     | X API v2 endpoint reference (~130 endpoints), OAuth2 scopes per operation, PAYG vs tweet-cap billing, rate-limit tables, agent-friendly `.md` doc URLs. `user-invocable: false`; auto-loads when bird is in context.                                  | (auto)                         |

**Routing rule:** if the task is about auth, the raw `xr` write-op transport, the X API endpoint shape, or what scope a
verb requires — that question belongs to one of those skills. This skill covers the value bird adds **on top of** them.

## Hard guardrail — production credentials

The installed `bird` binary on the user's machine runs against **real X API credentials** (token storage lives in xurl's
`~/.xurl`, not in bird). Every write op (`tweet`, `reply`, `like`, `unlike`, `repost`, `unrepost`, `follow`, `unfollow`,
`block`, `unblock`, `mute`, `unmute`, `dm`, `delete`, `post`, `put`) hits production state.

Before any write op:

1. Run with `--dry-run` first. bird prints the would-be request without sending and emits a typed envelope under
   `--output json`.
2. **Confirm scope with the user before issuing the live call** when the action is destructive (`delete`, `block`,
   `unfollow`, `dm` to anyone unfamiliar, `post`/`tweet` to anything besides a thread the user already named).
3. Prefer `--output json` with `--no-interactive` so failures arrive as a structured envelope you can act on instead of
   prompting on stdin.

bird ships an explicit confirmation gate for no-TTY callers: a write op without `--force`/`--yes` exits **2**
(`requires-confirmation`) rather than hanging. See `scripts/write-op-gate.sh` below for the wrapper.

Read ops (`me`, `bookmarks`, `profile`, `search`, `thread`, `get`, `watchlist list`, `watchlist fetch`, `usage`, `cache
stats`, `doctor`, `schema`) are safe to run without confirmation.

## Quick start — let the binary teach you

bird ships self-introspection on every subcommand. Reach for these before reading anything in `references/`:

```bash
bird --examples                            # curated invocation gallery for the root binary
bird <subcommand> --examples               # per-subcommand examples; works on every verb
bird <subcommand> --help                   # full flag matrix
bird schema --list --output json           # all output schema names: bookmarks, search, thread, profile, doctor, usage, watchlist, raw-get, success-envelope, error-envelope
bird schema <name> --output json           # full JSON Schema 2020-12 document for one shape
bird doctor --output json                  # xurl path/version, auth state, per-command availability, cache health
bird doctor <subcommand>                   # scoped diagnostics for one command
```

The output of `bird doctor` IS the answer to "is the environment ready?" — `xurl.available`, `auth.authenticated`,
`cache.healthy`, and a per-command `available` map with a `reason` field on every false. Trust the report over the
README.

## Routing table

| Task                                                               | First action                                                                                                              |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| Environment is broken (auth? xurl? cache?)                         | `bird doctor --output json` then [references/error-envelope.md](references/error-envelope.md)                             |
| User wants to search and rank by engagement                        | [templates/cached-search.md](templates/cached-search.md)                                                                  |
| User wants to poll a set of users for new activity                 | [templates/watchlist-monitor.md](templates/watchlist-monitor.md)                                                          |
| User wants to rebuild a conversation thread                        | `bird thread <tweet_id>` — see [references/cache-modes.md](references/cache-modes.md) for the `--cache-only` replay trick |
| User wants API cost / cap status                                   | [references/usage-and-cost.md](references/usage-and-cost.md)                                                              |
| Parse a response or an error envelope                              | [references/error-envelope.md](references/error-envelope.md)                                                              |
| Pick a cache mode (`--refresh` vs `--no-cache` vs `--cache-only`)  | [references/cache-modes.md](references/cache-modes.md)                                                                    |
| Validate a stored JSON file against bird's schema                  | `bird schema <name> --output json` → feed to a validator; see [references/schemas.md](references/schemas.md)              |
| User wants to write (tweet, reply, like, follow, dm, …)            | `scripts/write-op-gate.sh` + (for transport detail) the `xurl-rs` sibling skill                                           |
| Install / refresh this skill bundle into another host's skills dir | `bird skill install <host>` — see [references/skill-install.md](references/skill-install.md)                              |
| Stuck — what next?                                                 | [references/escalation.md](references/escalation.md)                                                                      |

## Iron rules

1. **Never invent X API endpoints, OAuth scopes, billing tiers, or rate-limit numbers.** They change and they live in
   the `x-api` companion skill or `https://docs.x.com/...md`. See [references/escalation.md](references/escalation.md)
   for the full lookup order.
2. **Never run a live write op without confirming scope with the user first**, OR without a successful `--dry-run` pass
   against the exact same flags first.
3. **Never paste credentials into chat, commits, PRs, or shell history.** bird does not store tokens; xurl does. Re-auth
   through `bird login` (delegates to xurl) or `xr auth oauth2`. Pass any inline secret through env vars (`$(op read
   op://...)`).
4. **Never re-implement xr functionality inside bird workflows.** If a task needs raw HTTP, streaming, OAuth1 signing,
   or media upload — that's xr's job. Defer to the `xurl-rs` skill.
5. **Read-only probes are always fine** without asking the user: `bird --help`, `bird <cmd> --help`, `bird --examples`,
   `bird <cmd> --examples`, `bird schema ...`, `bird doctor`, `bird cache stats`, `bird usage --local`, `bird watchlist
   list`. Run them as needed.

## Common flag patterns

Every subcommand inherits these globals. Each binds to a `BIRD_*` env var so non-interactive callers can configure bird
without touching argv. Full matrix → [references/agent-flags.md](references/agent-flags.md).

| Flag                                        | Env var                 | When to apply                                                                                 |
| ------------------------------------------- | ----------------------- | --------------------------------------------------------------------------------------------- |
| `--output {text,json,jsonl,ndjson}`         | `BIRD_OUTPUT`           | Always pass `json` for agent calls. Defaults to `text` on TTY, `json` when stderr is non-TTY. |
| `--no-interactive`                          | `BIRD_NO_INTERACTIVE=1` | Refuses anything that would block on stdin (paste-back OAuth, `[y/N]` prompts).               |
| `-q`, `--quiet`                             | `BIRD_QUIET=1`          | Suppress informational stderr banners; fatal errors still go to stderr.                       |
| `--timeout <secs>`                          | `BIRD_TIMEOUT`          | Default 30. Bump for slow networks; this flows through to the xurl subprocess.                |
| `--limit <N>` / `--cursor <TOKEN>`          | —                       | List-style commands. Responses surface `meta.next_cursor` for pagination resume.              |
| `--refresh` / `--no-cache` / `--cache-only` | —                       | Entity-store knobs; see [references/cache-modes.md](references/cache-modes.md).               |
| `-u`, `--username <name>`                   | `X_API_USERNAME`        | Multi-user token selection; passed through to xurl `-u`.                                      |

Two env vars without flag pairs:

- `BIRD_XURL_PATH` — override transport discovery with a direct path to an `xr` or `xurl` binary.
- `NO_COLOR=1` — strip ANSI color (industry standard; same effect as `--color never`).

## Scripts

| Script                                                         | Use for                                                                                                                                                                                                                                                            |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `scripts/write-op-gate.sh [--yes] -- bird <write-verb> [args]` | Every bird write op. Runs `--dry-run --output json` preflight, checks the envelope, prompts on TTY (or `--yes` off-TTY), then `exec`s the live call. Distinct from `xurl-rs`'s `dry-run-gate.sh` because bird's exit codes and envelope shape differ (kind=`config |

For paginating bird's list-style reads, you may use either:

- bird's own `--limit` + `--cursor` flags directly (responses surface `meta.next_cursor`), OR
- `xurl-rs`'s `paginate.sh` if installed — it works against bird identically because both emit the same `meta.next_*`
  shape on `--output json`.

Full contract: [scripts/README.md](scripts/README.md).

## Verifying the install

```bash
bird --version                              # prints "bird X.Y.Z"
bird doctor --output json                   # xurl.available + auth.authenticated + cache.healthy
bird schema --list --output json            # 10 schema names land in .data[]
```

If `xurl.available: false`, the xurl-rs binary is missing — install it from
<https://github.com/brettdavies/xurl-rs/releases> (or `brew install brettdavies/tap/xurl-rs`) and re-run `bird doctor`.
If `auth.authenticated: false`, run `bird login` to bounce through xurl's OAuth2 PKCE flow.

## Reference index

- [references/escalation.md](references/escalation.md) — when stuck: ordered lookup (bird → xr → x-api → official docs),
  iron rules, halt-vs-continue, worked examples.
- [references/cache-modes.md](references/cache-modes.md) — `--refresh` vs `--no-cache` vs `--cache-only`, TTL behavior,
  per-endpoint coverage, the `--cache-only` replay trick for offline analysis.
- [references/error-envelope.md](references/error-envelope.md) — JSON error shape (`kind`, `exit_code`, optional
  `command`/`status`/`reason`), the 0/1/2/77/78 exit-code split, mapping symptoms to fixes.
- [references/usage-and-cost.md](references/usage-and-cost.md) — `bird usage`, `--sync`, `--local`, `--since`,
  cost-ledger semantics, when to look at bird's local view vs the X API's authoritative one.
- [references/agent-flags.md](references/agent-flags.md) — full global-flag matrix, env-var precedence, output-format
  decision tree.
- [references/schemas.md](references/schemas.md) — the 10 schema names, embedded JSON Schema 2020-12 documents, how to
  pin against `https://bird.dev/schema/<name>-v1.json`, validation recipes.
- [references/skill-install.md](references/skill-install.md) — `bird skill install <host>` mechanics, the hardened
  clone, supported hosts, dry-run.
- [references/xr-bridge.md](references/xr-bridge.md) — what bird delegates to xr, the `BIRD_XURL_PATH` override, when to
  reach for the `xurl-rs` skill instead.

## Templates

- [templates/cached-search.md](templates/cached-search.md) — `bird search` with sort/min-likes/pages and cache-mode
  selection. Worked example covering "the same query repeated through the day" cost optimization.
- [templates/watchlist-monitor.md](templates/watchlist-monitor.md) — `bird watchlist add` → `fetch` polling loop with
  cron-friendly `--output jsonl` and `--no-interactive` flags.

## Producer-side notes

This file is the **consumer entry point** loaded into the agent's context when the skill activates. Producer-side notes
for agents working **on** this bundle (release flow, branch model, CI guards) live in [AGENTS.md](AGENTS.md). Don't
conflate the two.

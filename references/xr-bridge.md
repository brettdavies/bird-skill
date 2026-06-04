# xr bridge — what bird delegates and where to look

bird does not implement HTTP, OAuth, or any wire protocol. Every API call shells out to `xr` (xurl-rs) or `xurl` (Go
fallback) as a subprocess. This page maps **what bird hands off** to **where the answer lives** so you don't grep bird's
source for something that's xurl's job.

## Discovery order

bird picks the transport binary at first use:

1. `BIRD_XURL_PATH` environment override (a literal path to a binary). Wins absolutely.
2. `xr` on `$PATH` (the Rust xurl-rs).
3. `xurl` on `$PATH` (the Go original).
4. None found → exit 78 with `kind: "config"` and an install hint.

`bird doctor --output json` reports the resolved `xurl.path` and `xurl.version`. Minimum supported xurl version: 1.0.3.

## What bird sends to xr

For every API call, bird:

1. Picks the HTTP verb and path (or uses the verb the user passed for `bird get|post|put|delete`).
2. Resolves the auth requirement (`OAuth2User`, `OAuth1`, `Bearer`, `None`) from `src/requirements.rs` — single source
   of truth, also consumed by `bird doctor` for the per-command availability check.
3. Spawns xr with `-u <username>` (if multi-user), `--auth <scheme>`, the path, and the body (for writes).
4. Reads stdout (success envelope) or stderr (error envelope from xr) and translates into bird's envelope.

bird's `--username` flag, `--timeout` flag, and `BIRD_XURL_PATH` env are the only surface that crosses the bird/xr line
directly. Everything else inside the bird invocation stays in bird; everything in xr's invocation stays in xr.

## What bird does NOT do (use `xurl-rs` skill instead)

| If you need to...                                                                                         | Use this in the `xurl-rs` skill                                |
| --------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Configure OAuth2 PKCE for a fresh user (interactive or paste-back)                                        | `templates/oauth2-setup.md` and `references/auth-modes.md`     |
| Register a new X Developer app (`xr auth apps add`) or switch the default app                             | `references/auth-modes.md` § "multi-app token store"           |
| Force an auth scheme on one request (`xr --auth oauth1 /2/...`)                                           | `references/auth-modes.md` § "scheme override"                 |
| Inspect token freshness, refresh state, registered apps                                                   | `xr auth status --output json`; `references/auth-modes.md`     |
| Upload media in chunks and capture a `media_id`                                                           | `templates/media-upload.md`                                    |
| Stream filtered tweets (`xr -s /2/tweets/search/stream`)                                                  | `references/agent-flags.md` § "streaming"                      |
| Use the generic dry-run gate on a raw `xr` write verb                                                     | `scripts/dry-run-gate.sh`                                      |
| Paginate any xr list-style verb (works against bird too — both emit `meta.next_token`/`meta.next_cursor`) | `scripts/paginate.sh`                                          |
| Get the canonical agent-native envelope contract                                                          | `references/output-envelope.md`                                |
| Look up X API endpoints / scopes / billing tiers                                                          | `references/x-api-essentials.md` (or the `x-api` skill direct) |

If the user installs only this bird skill (no `xurl-rs` skill installed), the references above won't be on disk —
they'll only be reachable as URLs at <https://github.com/brettdavies/xurl-rs-skill>. The fix: run `xr skill install
claude_code` (or the host equivalent) to drop them at `~/.claude/skills/xurl-rs/`.

## What bird wraps better than xr

bird adds value xr doesn't have on top of the same transport:

- **Per-endpoint entity cache** — `xr` doesn't cache; bird does. See [cache-modes.md](cache-modes.md).
- **Watchlist** — `xr` has no concept of "polling a set of users."
- **Thread reconstruction** — `xr` exposes `/2/tweets/<id>/quote_tweets` and `/conversation_id` lookups; bird stitches
  them into an ordered thread.
- **Local cost ledger** — `xr` doesn't track per-call spend. See [usage-and-cost.md](usage-and-cost.md).
- **Structured `bird doctor` self-diagnostics** with per-command availability.
- **Search ergonomics** — `--sort likes --min-likes N --pages N` is bird's, not xr's.
- **JSON Schema documents per output shape** via `bird schema`. xr's schemas describe xr's output, not bird's.

When the task uses any of the above, **stay in bird** — don't drop down to xr for that step. Mixing bird's cache with
raw xr calls is the classic way to get a stale read followed by a fresh write that disagrees with the cache.

## Bypassing bird for one call

When you genuinely need `xr` (a feature bird doesn't wrap, like media upload), and you want the call to share bird's
multi-user token selection:

```bash
xr -u "$(bird doctor --output json | jaq -r '.data.config.username // ""')" media upload ./image.png --output json
```

bird doesn't have a `--passthrough` mode; calling `xr` directly is the right move.

## When `bird` and `xr` disagree

If `bird doctor` says `auth.authenticated: true` but `xr auth status` says otherwise (or vice versa), the truth is on
xr's side — bird is reporting what its `requirements.rs` thinks given the xurl version it found, but xurl's token store
is authoritative. Resolve in this order:

1. `xr auth status --output json` — what tokens does xurl actually have?
2. `bird doctor --output json` — what does bird's command-availability matrix show?
3. If they disagree and the xr side is "authenticated, all good," the fix is in bird — file at
   <https://github.com/brettdavies/bird/issues> with both envelopes.
4. If the xr side is "missing or expired," the fix is on the xurl side — re-auth via the `xurl-rs` skill's OAuth2 PKCE
   template, then re-run `bird doctor` to confirm bird sees the new state.

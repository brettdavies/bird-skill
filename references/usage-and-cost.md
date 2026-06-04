# Usage and cost ledger

bird tracks API spend in two parallel views:

- **The X API's authoritative usage endpoint** — what the platform thinks you've consumed. Authoritative; requires
  Bearer auth. Surfaced by `bird usage` (sync mode) and `bird usage --sync`.
- **bird's local cost ledger** — every API-touching invocation appends a row with the endpoint, the response size, and
  an estimated dollar cost based on bird's per-shape rate table. Surfaced by `bird usage --local`.

The two views differ. The API is the source of truth for caps and rate limits. The local ledger is the source of truth
for "what did MY calls actually look like, broken down by command and time" — which the API doesn't expose.

## Commands

```bash
bird usage                                    # syncs from the API, then prints text
bird usage --output json                      # same, machine-readable
bird usage --since 2026-05-01                 # bound the window (default: last 30 days)
bird usage --local                            # local ledger only, no API sync
bird usage --local --since 2026-05-01 --output json
bird usage --sync --output json               # force-sync even if recently cached
bird usage --pretty                           # human-friendly columns
```

The default mode (`bird usage` with no flags) **does** hit the API on each invocation. If the user is in a hot loop or
you suspect the sync itself is the cost driver, prefer `--local`.

## When to use which view

| Question                                                            | View  | Command                                            |
| ------------------------------------------------------------------- | ----- | -------------------------------------------------- |
| "Am I rate-limited right now?"                                      | API   | `bird usage --output json`                         |
| "How close am I to the monthly cap?"                                | API   | `bird usage --output json`                         |
| "Which command burned the most credits today?"                      | local | `bird usage --local --output json`                 |
| "Did my last `--pages 10` search actually cost me what I expected?" | local | `bird usage --local --since <today> --output json` |
| "Bearer is broken; I just want to see local data"                   | local | `bird usage --local --output json`                 |
| "I'm planning a big sweep; what's the headroom?"                    | both  | API for cap status, local for per-call rate.       |

## Schema

`bird schema usage --output json` prints the full document. The envelope's `.data` shape (paraphrased):

```json
{
  "data": {
    "window": {"start": "2026-05-05T00:00:00Z", "end": "2026-06-04T18:00:00Z"},
    "api": {
      "available": true,
      "tier": "<tier name, when known>",
      "post_cap": {"limit": 10000, "consumed": 1234},
      "pull_cap": {"limit": 100000, "consumed": 15600}
    },
    "local": {
      "calls": 412,
      "estimated_cost_usd": 1.23,
      "by_command": [
        {"command": "search", "calls": 180, "cost_usd": 0.90},
        {"command": "bookmarks", "calls": 100, "cost_usd": 0.20},
        {"command": "me", "calls": 132, "cost_usd": 0.13}
      ],
      "by_day": [{"day": "2026-06-04", "calls": 38, "cost_usd": 0.11}]
    }
  },
  "meta": {}
}
```

The `local` block is always present and never requires Bearer. The `api` block requires Bearer; if `api.available` is
false, the envelope still returns 0 and the `error` field carries the reason (e.g., `"bearer-not-configured"`). Treat
that as a soft failure on the API view, not a hard error.

## Cost-estimation caveats

bird's local cost numbers are **estimates** built from bird's per-shape rate table. They will drift from the
authoritative API numbers when:

- Endpoint pricing changes upstream and bird's table hasn't been updated.
- A request returned cached data (no cost) but the local ledger still records the entry (cost=0 for cache hits — verify
  with `--local --output json` to see the `cost_usd` per-row).
- Streaming endpoints (handled by `xr` directly, not bird) won't appear in bird's ledger at all.

When the two views disagree by more than ~10%, trust the API view and consider filing a bird issue with both envelopes
attached so the rate table can be tuned.

## Cost-aware workflow guidance

- Default to read-through caching. A `bird search` repeated within the TTL window is free.
- Use `--cache-only` for replay analysis; it bypasses both the API and the local-ledger write.
- For bulk sweeps, prefer `--pages 5` over five separate invocations — fewer round-trips, smaller envelope overhead, the
  same cap consumption.
- The `xurl-rs` skill's `paginate.sh` works against bird unchanged; for very large list sweeps, set its `--sleep` to
  stay under the per-window limit.

## When `bird usage --sync` fails

Most common failure: `kind: "auth"`, exit 77, with a message about Bearer. The Usage endpoint requires Bearer auth
specifically, not the OAuth2 user-context token bird uses for most reads. Resolution lives on the xurl side:

1. Route to the `xurl-rs` skill's `references/auth-modes.md` for the Bearer setup procedure.
2. After Bearer is configured, `bird usage --output json` should sync cleanly.
3. Until then, `bird usage --local` keeps working — local-only never needs Bearer.

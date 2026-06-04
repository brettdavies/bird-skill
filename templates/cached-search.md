# Template — cached search with sort, threshold, and replay

Use bird's `search` ergonomics (`--sort likes --min-likes N --pages N`) plus its entity cache to run the same query
multiple times in a day without burning quota.

## Quick template

```bash
QUERY="rustlang has:links -is:retweet"

# First pass: 5 pages, sort by likes, drop low-engagement noise. Fills the cache as a side effect.
bird search "$QUERY" \
  --sort likes --min-likes 50 --pages 5 \
  --output jsonl > /tmp/search.jsonl

# Inspect counts.
jaq -nc 'inputs | .data[] | {id, like_count: .public_metrics.like_count, text: .text}' /tmp/search.jsonl | head

# Replay later in the same TTL window — no API calls, no cost.
bird search "$QUERY" \
  --sort likes --min-likes 50 --pages 5 --cache-only \
  --output jsonl > /tmp/search.replay.jsonl

diff /tmp/search.jsonl /tmp/search.replay.jsonl   # should be empty
```

## Decision: when to pass which flag

| User intent                                                     | Flags                                         |
| --------------------------------------------------------------- | --------------------------------------------- |
| "Show me what's trending in this query right now"               | (default — read-through cache, fresh on miss) |
| "Force a re-fetch, my last result is stale"                     | `--refresh`                                   |
| "I'm doing controlled analysis; the cache must not affect this" | `--no-cache`                                  |
| "I'm offline / rate-limited; show me what's stored"             | `--cache-only`                                |
| "Top engagement first, ignore low-likes"                        | `--sort likes --min-likes <N>`                |
| "Walk multiple pages of results in one go"                      | `--pages <N>` (cap: 10)                       |
| "Cap total record count regardless of pages"                    | `--limit <N>`                                 |
| "Stream as I get them, don't buffer"                            | `--output jsonl`                              |

`--sort recent` is the default; `--sort likes` performs a client-side sort on the pages fetched (it does **not** ask the
API for engagement-ranked results — those don't exist for `recent search`). For a much wider engagement sweep, increase
`--pages` first, then sort.

## Watch out for

- **`--min-likes` is a post-filter**, not an API parameter. The pages still cost what they cost; the threshold just
  drops records before printing. If you're cost-sensitive, narrow the query (`has:links`, `-is:retweet`, `lang:en`)
  before lowering `--min-likes`.
- **Cache hits do not increment the local cost ledger** beyond the `cost_usd: 0` row. If `bird usage --local` shows a
  surprising count, look at the per-day breakdown to see whether they were cache or API.
- **`--cache-only` errors on miss** with `kind: "command"`, `error: "cache miss: ..."`, exit code 1. Treat as a
  recoverable signal, not a fatal — fall through to the default mode if the user wants the data either way.

## Walkthrough — "run every morning, replay later"

A common pattern: pull a snapshot at 9am, replay it through the day to chase context without re-spending.

```bash
# 09:00 — fresh snapshot
bird search "from:claudeai" --pages 10 --output jsonl > "/tmp/claudeai-$(date +%Y%m%d).jsonl"

# 13:00 — same query, no spend
bird search "from:claudeai" --pages 10 --cache-only --output jsonl

# 17:00 — refresh and diff
bird search "from:claudeai" --pages 10 --refresh --output jsonl > "/tmp/claudeai-$(date +%Y%m%d)-1700.jsonl"
diff "/tmp/claudeai-$(date +%Y%m%d).jsonl" "/tmp/claudeai-$(date +%Y%m%d)-1700.jsonl" | head
```

## Composing with the `xurl-rs` skill

For very large result sweeps, `xurl-rs`'s `paginate.sh` works against bird identically because the `meta.next_cursor`
shape is shared:

```bash
~/.claude/skills/xurl-rs/scripts/paginate.sh --max-pages 20 -- \
  bird search "$QUERY" --output jsonl
```

The script caps at `--max-pages` and emits the resume cursor on stderr when capped, so you can pick up where you left
off without losing position.

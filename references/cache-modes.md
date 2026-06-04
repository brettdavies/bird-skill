# Cache modes — the entity store knobs

bird ships a SQLite entity store at `~/.config/bird/bird.db` (mode 0600) that sits in front of every read command. Three
mutually exclusive global flags control how a single invocation interacts with it. Default behavior — when none of the
three are set — is read-through caching with per-endpoint TTL.

| Mode           | Reads the cache? | Writes the cache? | Hits the API? | When to use                                                                                                      |
| -------------- | ---------------- | ----------------- | ------------- | ---------------------------------------------------------------------------------------------------------------- |
| default        | yes              | yes               | only on miss  | Day-to-day. Cheapest path.                                                                                       |
| `--refresh`    | no               | yes               | always        | Suspect the cache is stale. Re-fetches and updates the store.                                                    |
| `--no-cache`   | no               | no                | always        | Audit / repro: the answer must come from the API, and you don't want to dirty the cache.                         |
| `--cache-only` | yes              | no                | never         | Offline analysis, replay of an earlier run, or "I'm rate-limited and only need cached entities." Errors on miss. |

Write commands (`tweet`, `reply`, `like`, `unlike`, `repost`, `unrepost`, `follow`, `unfollow`, `block`, `unblock`,
`mute`, `unmute`, `dm`, `delete`, `post`, `put`) **reject `--cache-only`** with `kind: "command"` exit 1 — you cannot
mutate state from cache. They also bypass cache read by definition; `--refresh` and `--no-cache` are no-ops on writes.

## Per-endpoint coverage

`bird cache stats --output json` reports counters by entity shape. The current set:

```json
{
  "data": {
    "path": "~/.config/bird/bird.db",
    "exists": true,
    "size_mb": 0.7,
    "max_size_mb": 100,
    "tweets": 415,
    "users": 224,
    "raw_responses": 0,
    "healthy": true
  },
  "meta": {}
}
```

- **`tweets`** — populated by `bird bookmarks`, `bird search`, `bird thread`, and any `bird get` that returns a
  tweet-shaped response.
- **`users`** — populated by `bird me`, `bird profile`, watchlist fetches, expansion lookups.
- **`raw_responses`** — populated by `bird get` against arbitrary paths when the response doesn't match a known entity
  shape.

The store enforces a soft cap of `max_size_mb` (default 100). `bird cache stats` reports `healthy: false` when the cap
is exceeded, and `bird cache clear` wipes the whole store. There is currently no per-entity expiry knob; TTL is per
endpoint and built into the client modules.

## The `--cache-only` replay trick

Useful patterns:

```bash
# 1. Fetch and cache once.
bird search "rustlang has:links" --pages 5 --output jsonl > /tmp/today.jsonl

# 2. Re-run the same query offline against the same data. No API spend, no auth required.
bird search "rustlang has:links" --pages 5 --cache-only --output jsonl > /tmp/replay.jsonl
diff /tmp/today.jsonl /tmp/replay.jsonl   # should be empty

# 3. Hours later, you suspect the data changed. Force a refresh and compare:
bird search "rustlang has:links" --pages 5 --refresh --output jsonl > /tmp/refreshed.jsonl
diff /tmp/today.jsonl /tmp/refreshed.jsonl   # the delta is the change since the first fetch
```

`--cache-only` on a miss returns:

```json
{
  "error": "cache miss: no entity for /2/tweets/search/recent?query=rustlang+has%3Alinks",
  "kind": "command",
  "command": "search",
  "exit_code": 1,
  "meta": {}
}
```

Use the absence of `meta.next_cursor` in a `--cache-only` response as the signal that you've exhausted what was cached
during the original sweep.

## Cache + `--refresh` interaction on writes

A common confusion: agents sometimes pass `--refresh` to write verbs hoping it'll bust a stale identity cache after a
profile change. It doesn't — writes don't read the cache, and a write to `bird tweet` cannot invalidate the cached
`/2/users/me` entry. The right pattern is `bird me --refresh --output json` **before** the write to refresh the
identity, then issue the write.

## Inspecting cache health

```bash
bird cache stats                            # default text
bird cache stats --pretty                   # human-friendly columns
bird cache stats --output json              # the envelope shape above

bird cache clear                            # delete every row. Asks for [y/N] on TTY; --no-interactive refuses without --force.
bird cache clear --force --output json      # scripted wipe; the envelope reports rows_deleted.
```

A `healthy: false` report most often means the file grew past `max_size_mb`. Treat it as a signal to `clear` and let the
store rebuild from natural read traffic.

## Where the cache file lives

| Path                         | Mode | Owner             |
| ---------------------------- | ---- | ----------------- |
| `~/.config/bird/bird.db`     | 0600 | the invoking user |
| `~/.config/bird/config.toml` | 0644 | the invoking user |

bird sets these permissions on first use (`#[cfg(unix)]`); on a system where they've drifted, `bird doctor` reports the
drift under the `cache` block.

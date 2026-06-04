# Template — watchlist monitoring loop

`bird watchlist` is bird's "poll a small set of users for new activity" feature. No equivalent in `xr` or the raw X API.
The cron-friendly recipe is below.

## Setup (one-time)

```bash
# Add users by handle. Strip leading @ if you want — bird does too.
bird watchlist add jack
bird watchlist add @elonmusk
bird watchlist add claudeai

# Confirm.
bird watchlist list --output json
```

The watchlist lives in `~/.config/bird/config.toml`. Edit by hand if you prefer; bird re-reads on every invocation.

## Foreground check

```bash
bird watchlist fetch                          # default: text on TTY
bird watchlist fetch --output json            # paired JSON
bird watchlist fetch --output jsonl           # streaming (one record per user)
bird watchlist fetch --pretty                 # ANSI columns
```

`fetch` is the canonical verb; `check` survives as an alias for backward compatibility. The response is per-user, with
`new_since_last_check` and per-user error reasons so a single rate-limited account doesn't blank the report.

## Cron-friendly recipe

```bash
#!/usr/bin/env bash
# /etc/cron.hourly/bird-watch
set -euo pipefail

export BIRD_OUTPUT=json
export BIRD_QUIET=1
export BIRD_NO_INTERACTIVE=1

bird watchlist fetch \
  | jaq -c '.data[] | select(.new_since_last_check | length > 0)' \
  >> /var/log/bird-watch.jsonl
```

Why each flag matters:

- `BIRD_OUTPUT=json` — agent-parseable; cron has no TTY so this is also the default, but be explicit.
- `BIRD_QUIET=1` — drops bird's stderr banners; only fatal errors land in cron mail.
- `BIRD_NO_INTERACTIVE=1` — if auth has expired and bird wants to bounce through `bird login`, this exits non-zero with
  `kind: "auth"` instead of hanging waiting for a browser.

## When auth expires inside a watchlist loop

A common failure on long-running cron loops: the OAuth2 token expires, `bird watchlist fetch` exits 77, cron mails you,
and nothing's been logged since.

Robust pattern:

```bash
if ! bird watchlist fetch > /tmp/watch.json 2>/tmp/watch.err; then
  KIND=$(jaq -r '.kind' /tmp/watch.err)
  case "$KIND" in
    auth) logger -t bird "watchlist: auth expired; needs `bird login` (or `xr auth oauth2 --no-browser`)" ;;
    config) logger -t bird "watchlist: config error; check BIRD_XURL_PATH and `bird doctor`" ;;
    command) logger -t bird "watchlist: command error: $(jaq -r '.error' /tmp/watch.err)" ;;
    *) logger -t bird "watchlist: unknown failure" ;;
  esac
  exit 1
fi
```

For the recovery procedure (re-auth flow), route to the `xurl-rs` skill's `templates/oauth2-setup.md` — bird's `login`
is a thin passthrough.

## Watchlist + cache interaction

`bird watchlist fetch` populates the cache for every user it sees. Subsequent `bird profile <watched-user>` reads will
hit cache. That's usually desirable. If you want a watchlist check that does NOT pollute the cache (e.g., one-off audit
run on accounts you don't normally track), pass `--no-cache`:

```bash
bird watchlist fetch --no-cache --output json
```

## Removing and disabling

```bash
bird watchlist remove jack                    # one user
bird watchlist remove @elonmusk
bird watchlist list --output json | jaq '.data | length'    # confirm
```

There is no global "disable polling" flag — if you don't want the cron to run, disable the cron. bird itself only acts
on `bird watchlist fetch` (or aliases); the watchlist file is inert otherwise.

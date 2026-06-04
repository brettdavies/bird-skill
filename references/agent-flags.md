# Agent flags — the global flag matrix

Every bird subcommand inherits these flags. Each binds to a `BIRD_*` environment variable so non-interactive callers can
configure bird without touching argv. The flag wins when both are set.

## Output and formatting

| Flag                                | Env var        | Default                                      | Notes                                                                                             |
| ----------------------------------- | -------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `--output {text,json,jsonl,ndjson}` | `BIRD_OUTPUT`  | `text` on TTY, `json` when stderr is non-TTY | `ndjson` is an accepted alias for `jsonl`.                                                        |
| `--json`                            | `BIRD_JSON=1`  | unset                                        | Shorthand for `--output json`.                                                                    |
| `--jsonl`                           | `BIRD_JSONL=1` | unset                                        | Shorthand for `--output jsonl`. Useful for piping into `jaq -nc 'inputs                           |
| `--pretty`                          | —              | unset                                        | Pretty-print text output with ANSI color + OSC-8 hyperlinks. Ignored when `--output` is non-text. |
| `--color {auto,always,never}`       | `BIRD_COLOR`   | `auto`                                       | `NO_COLOR=1` forces `never`. `--plain` and `--no-color` are hidden aliases for `--color never`.   |
| `--raw`                             | —              | unset                                        | Pipe-safe undecorated text. Ignored in JSON modes.                                                |

## Behavior

| Flag               | Env var                 | Default | Notes                                                                           |
| ------------------ | ----------------------- | ------- | ------------------------------------------------------------------------------- |
| `-q`, `--quiet`    | `BIRD_QUIET=1`          | unset   | Suppresses informational stderr banners; fatal errors still go to stderr.       |
| `-v`, `--verbose`  | `BIRD_VERBOSE=<count>`  | 0       | Repeatable: `-v` info, `-vv` debug, `-vvv` trace.                               |
| `--timeout <secs>` | `BIRD_TIMEOUT`          | 30      | Network timeout for xurl subprocesses. Bump for slow networks or streaming.     |
| `--no-interactive` | `BIRD_NO_INTERACTIVE=1` | unset   | Refuses anything that would block on stdin (`[y/N]` prompts, paste-back OAuth). |

## Cache modes

| Flag           | Description                                                                       |
| -------------- | --------------------------------------------------------------------------------- |
| `--refresh`    | Bypass cache read; still write the fresh response back.                           |
| `--no-cache`   | Disable cache entirely (no read, no write).                                       |
| `--cache-only` | Read from cache only; never hit the API. Errors on miss; rejected on write verbs. |

The three are mutually exclusive. Full semantics: [cache-modes.md](cache-modes.md).

## Pagination

| Flag             | Description                                                                          |
| ---------------- | ------------------------------------------------------------------------------------ |
| `--limit <N>`    | Cap for list-style commands. Default 100. Ceiling 1000.                              |
| `--cursor <TOK>` | Pagination cursor (alias `--page`). Responses surface `meta.next_cursor` for resume. |

Per-command flags (`bird search --pages N`, `bird thread --max-pages N`) cap the **number of API pages walked** in a
single invocation; `--limit` caps the **number of records returned**.

## Account selection

| Flag                      | Env var          | Notes                                                                                   |
| ------------------------- | ---------------- | --------------------------------------------------------------------------------------- |
| `-u`, `--username <name>` | `X_API_USERNAME` | Multi-user token selection; passed through to xurl `-u`. Priority: flag > config > env. |

## Self-introspection

| Flag           | Description                                                                                        |
| -------------- | -------------------------------------------------------------------------------------------------- |
| `--examples`   | Print the curated examples block for the current binary or subcommand and exit zero.               |
| `-h`, `--help` | Standard clap help. Every subcommand's `--help` ends with `Examples:` (typically 3-5 invocations). |
| `--version`    | Prints `bird X.Y.Z`.                                                                               |

## Two env vars without flag pairs

- **`BIRD_XURL_PATH`** — override transport discovery with a direct path to an `xr` or `xurl` binary. Useful for
  development against a non-installed build, or for pinning to a specific xurl version in CI.
- **`NO_COLOR=1`** — industry-standard ANSI strip. Same effect as `--color never`.

## Output-format decision tree for agents

1. **Single record, parsed once** → `--output json`, parse with `jaq '.data'`.
2. **Streaming over many records (search, bookmarks, watchlist fetch)** → `--output jsonl`, pipe through `jaq -nc
   'inputs | .data[] | ...'`.
3. **Human-eyeable preview** → omit `--output` (TTY auto-text) or pass `--pretty` for ANSI.
4. **Quick existence/availability check** → `--output json --quiet | jaq -e '.data.<key>'`. The `-e` exit code is the
   answer.

## Env precedence — flag wins, then env, then default

```text
flag passed?      yes -> use flag value
flag not passed?  BIRD_<key> set? yes -> use env value
                  not set?        -> use compiled default
```

The only exception is `BIRD_OUTPUT=text` on a non-TTY: that loses to the non-TTY auto-promotion to JSON for stderr error
envelopes (the success envelope on stdout still respects `text`). The asymmetry is deliberate — agents that forget to
set `--output json` still get parseable errors.

## What lives on the **xurl-rs** side instead

These are xurl knobs that bird passes through but does not own. Read the `xurl-rs` skill's `references/agent-flags.md`
for the full set:

- `--auth {oauth1,oauth2,app}` — pick an auth scheme per request (xr only; bird picks per-command automatically).
- `--app <name>` — multi-app override (xr only).
- xr's `XURL_OUTPUT`, `XURL_BEARER_TOKEN`, `XURL_CLIENT_*` envs — not consumed by bird directly; xurl handles them
  inside the subprocess.

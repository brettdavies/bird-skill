# Error envelope and exit codes

bird emits structured JSON errors on **stderr** under `--output json` (or when stderr is non-TTY and `BIRD_OUTPUT` is
unset — bird auto-promotes to JSON for non-interactive callers). The envelope is the contract; the exit code is the
fast-path signal.

## Envelope shape

```json
{
  "error": "human-readable message",
  "kind": "config | auth | command",
  "exit_code": 0 | 1 | 2 | 77 | 78,
  "message": "duplicate of `error` for envelope-consistency tools",
  "command": "<subcommand name, only present for kind=command>",
  "status": "<HTTP status, only present for command + API failures>",
  "reason": "<optional machine-readable reason slug — e.g. requires-confirmation, missing-host, cache-miss>",
  "meta": {}
}
```

Stable keys: `error`, `kind`, `exit_code`, `meta`. Conditional keys: `command` (when `kind=command`), `status` (when the
upstream HTTP status is known), `reason` (when bird has a slug-shaped explanation).

`bird schema error-envelope --output json` prints the authoritative JSON Schema. Pin against that, not against this
file.

## Exit codes (BSD sysexits-aligned)

| Code | Meaning                             | When                                                                                             | First action                                                                                                          |
| ---- | ----------------------------------- | ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| 0    | Success                             | The op completed; envelope `status: "ok"`.                                                       | Parse `.data` / `.meta`.                                                                                              |
| 2    | `requires-confirmation`             | No-TTY caller hit a write op without `--force`/`--yes`.                                          | Confirm scope with the user, then re-run with `--force`, OR wrap with `scripts/write-op-gate.sh --yes`.               |
| 77   | Auth error (`sysexits` EX_NOPERM)   | `XurlError::Auth` from the xurl subprocess — HTTP 401/403 or token expired.                      | `bird doctor` to confirm; `bird login` to re-auth; for token-store debug, route to `xurl-rs` skill's `auth-modes.md`. |
| 78   | Config error (`sysexits` EX_CONFIG) | Missing xurl binary, invalid `~/.config/bird/config.toml`, bad `BIRD_XURL_PATH`, malformed flag. | `bird doctor --output json` and check `xurl.available`; install or path-fix; re-run.                                  |
| 1    | Generic command error               | API failure, network error, I/O failure, anything that doesn't fit the buckets above.            | Inspect `.status` (if present) and the message; differentiate API-side (4xx/5xx) from local I/O.                      |

The 77/78 split exists so agent harnesses can branch cleanly between "fix your tokens" and "fix your config" without
regex-matching the message. Exit 2 lets non-interactive callers gate destructive ops explicitly instead of hanging on
stdin.

## Mapping symptoms to fixes

| Envelope                                                                            | Fix                                                                                                                                 |
| ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `kind: "config", exit_code: 78, error: "xurl not found"`                            | Install xurl-rs: `brew install brettdavies/tap/xurl-rs` (or download from the releases page). Re-run `bird doctor`.                 |
| `kind: "config", exit_code: 78, error: "BIRD_XURL_PATH points to a non-executable"` | `ls -la $BIRD_XURL_PATH`; either chmod +x or unset the override and let discovery fall back to PATH.                                |
| `kind: "auth", exit_code: 77, error: "..."`, no `status`                            | xurl returned an auth error before HTTP — token missing or refresh failed. `bird login`.                                            |
| `kind: "auth", exit_code: 77, error: "...", status: 401`                            | Token expired or revoked. `bird login` (OAuth2 PKCE) or, for headless, `bird login --no-browser`.                                   |
| `kind: "auth", exit_code: 77, error: "...", status: 403`                            | Authenticated but missing scope. Check the `x-api` skill for the scope this verb needs, then re-auth with that scope granted.       |
| `kind: "command", exit_code: 1, status: 429`                                        | Rate-limited. `bird usage --output json` to see whether it's per-window or cap-of-day; back off accordingly.                        |
| `kind: "command", exit_code: 1, command: "search", error: "...CreditsDepleted..."`  | PAYG balance exhausted (not the tweet cap). Add funds in the X Developer Portal; meanwhile, `--cache-only` to keep working offline. |
| `kind: "command", exit_code: 2, reason: "requires-confirmation"`                    | No-TTY caller hit a write op. Confirm with the user; re-run with `--force`, or use `scripts/write-op-gate.sh --yes`.                |
| `kind: "command", exit_code: 2, reason: "missing-host"` from `bird skill install`   | No `<host>` and no `--all` supplied. Re-run with one of `claude_code                                                                |
| `kind: "command", exit_code: 1, command: "search", error: "cache miss: ..."`        | `--cache-only` was set and the entity isn't in the store. Drop `--cache-only` (or pre-populate with one default-mode read).         |

## What bird does NOT do

- bird never **swallows** an error. A failure mode you can't classify from the envelope is a bird bug; file at
  <https://github.com/brettdavies/bird/issues> with the envelope and `bird doctor --output json` attached.
- bird does not re-shape xurl's errors beyond mapping `XurlError::Auth` to exit 77. If you need xurl-side context
  (multi-app token store, OAuth1 signing details, app-not-registered errors), the `xurl-rs` skill's
  `references/output-envelope.md` owns that material.

## Quick stderr/stdout split reminder

bird emits the **success envelope** on stdout and the **error envelope** on stderr, both under `--output json`. The
common parsing pattern:

```bash
RESP=$(bird search "rustlang" --output json 2> /tmp/err.json)
if [[ $? -eq 0 ]]; then
  echo "$RESP" | jaq '.data | length'
else
  jaq '.kind + ":" + (.exit_code | tostring) + " " + .error' /tmp/err.json
fi
```

When stderr is not a TTY and `BIRD_OUTPUT` is unset, bird auto-promotes to `json` on the error path too — agents almost
always get the envelope without explicitly setting `--output json`. Set it explicitly anyway for clarity.

# Escalation — when you're stuck

bird and this bundle cover the common cases. Edge cases happen. This file names the lookup order so you don't guess.

## Lookup order

Walk these in order. Stop at the first one that answers the question.

1. **`bird <command> --help`** — current with the installed bird version. Every subcommand documents its flags and ends
   with an `Examples:` block.
2. **`bird --examples`** and **`bird <command> --examples`** — the curated invocation gallery, per binary and per
   subcommand. When the question is "what does the canonical pattern look like?", this is the answer.
3. **`bird doctor --output json`** — environment health: xurl path/version, auth state, per-command availability with a
   `reason` field on every false, cache health. Run before assuming bird is broken.
4. **`bird schema --list --output json`** then **`bird schema <name> --output json`** — JSON Schema 2020-12 documents
   for every output shape. When the question is "what fields can I rely on?" or "does my parser handle the right keys?",
   this is the answer.
5. **`bird usage --output json`** (or `bird usage --local`) — current cap status and local cost ledger. When you hit a
   rate-limit or `CreditsDepleted` error, look here before re-running.
6. **The `xurl-rs` companion skill** — for everything that crosses the wire: OAuth2 PKCE setup, multi-app token store,
   `xr` write-op shapes, dry-run-gate.sh, paginate.sh, the output envelope. bird delegates auth and HTTP to `xr`; auth /
   transport questions resolve there, not here.
7. **The `x-api` companion skill** — endpoint reference, OAuth2 scopes per operation, PAYG vs cap billing, rate-limit
   tables. Auto-loads when bird is in context. When the question is "what scope does verb X need?" or "which endpoint
   does the `usage` API hit?", this is the answer.
8. **Official X docs** — every page supports markdown by appending `.md` to the URL. The index is
   <https://docs.x.com/llms.txt>. Use `defuddle` (or the agent's `fetch-web` skill) to clean MDX.
9. **Upstream bird issues** — <https://github.com/brettdavies/bird/issues>. Skill-bundle issues (stale references, wrong
   invocations, missing templates) live at <https://github.com/brettdavies/bird-skill/issues> with a `[skill]` prefix in
   the title.
10. **Ask the user** — last resort, only when the answer requires user-side context (which thread to post to, which
    account to act as, whether to proceed with a destructive op).

## Iron rule — what to never invent

**Never invent X API endpoint paths, OAuth scopes, billing tiers, or rate-limit numbers.** They change. They are not in
bird's scope to describe authoritatively — they live in the `x-api` skill or `docs.x.com`. Always resolve via the lookup
order above.

This rule has two carve-outs so it doesn't over-constrain:

- **Read-only probes are always fine** without asking the user: `bird --help`, `bird <cmd> --help`, `bird --examples`,
  `bird <cmd> --examples`, `bird schema ...`, `bird doctor`, `bird cache stats`, `bird watchlist list`, `bird usage
  --local`, `bird --version`, fetching a docs page from `docs.x.com/.../<page>.md`. Run them as needed.
- **bird's own contract** (output formats, exit codes 0/1/2/77/78, the error envelope keys, cache-mode flags, `--limit`
  / `--cursor` pagination, the `bird skill install` host list) is fine to cite from `bird --help` and this bundle. Those
  are stable per bird major version.

## Halt vs continue

**Halt and ask the user** when:

- The action is destructive (`delete`, `block`, `unfollow`, `dm` to anyone unfamiliar, `tweet`/`reply`/`post` to
  anything besides a thread the user named).
- Authentication is missing (`bird doctor` shows `auth.authenticated: false`) for a verb that requires user context.
- The user's intent ambiguously maps to multiple commands (e.g., "show me my activity" — `bird me`? `bird bookmarks`?
  `bird get /2/users/me/mentions`?).
- An error envelope returns `kind: "command"` with `status: 429` (rate-limited) and the agent does not know whether to
  wait or to pivot.
- A write op exits 2 (`requires-confirmation`) and `--force` was not provided — the gate is doing its job; surface the
  intent before bypassing it.

**Continue without asking** when:

- The action is read-only, the credentials are present, and the user's intent maps unambiguously to one command.
- A `--dry-run` envelope has already returned a clean result and the user has authorized the live call.
- The fix for a `kind: "config"` envelope (exit 78) is mechanically derivable — a `BIRD_XURL_PATH` typo, a missing
  config file the binary will create on first run.
- `--cache-only` returned a hit and the user only asked for cached data.

## Worked examples

### "How do I run bird against a different xurl binary?"

1. `bird doctor --output json` → look at `xurl.path` and `xurl.version`.
2. `bird --help` → confirms `BIRD_XURL_PATH` env var overrides discovery.
3. `BIRD_XURL_PATH=/path/to/other/xurl bird doctor --output json` → confirm the override took.

Done at step 2; the lookup short-circuits. No need to read source.

### "Why is `bird usage` returning stale numbers?"

1. `bird usage --help` → `--sync` refreshes from the X API; `--local` skips the API entirely.
2. `bird usage --local --output json` → confirms what bird has locally.
3. `bird usage --output json` (without `--local`) → re-syncs from the API by default and reports the authoritative
   number. If the sync fails with `kind: "auth"` (exit 77), Bearer is missing — that's an xurl-side fix; route to the
   `xurl-rs` skill's `auth-modes.md`.
4. If still puzzled: `bird usage --since 2026-05-01 --output json` to inspect a date range; cross-check against the X
   API docs page (`https://docs.x.com/x-api/usage/get-usage.md`).

### "What scope does `bird dm` need?"

1. `bird dm --help` → describes the bird CLI surface, not the scope.
2. `bird --examples` → shows the invocation, not the scope.
3. **`x-api` companion skill** — has the OAuth2-scope-per-operation table. `dm.write` (or the current scope name) is in
   that table.
4. Fall through to <https://docs.x.com/x-api/direct-messages/introduction.md>.

Do not guess the scope name. The agent that guesses `dm.write` when the real one is `dm.write.send` is the agent that
wastes a token refresh and an hour debugging an `auth-required` envelope.

### "`bird thread` returned 12 tweets but the thread is clearly longer."

1. `bird thread --help` → `--max-pages <N>` caps the sweep; default is 5.
2. Re-run with `--max-pages 25 --output json` to widen.
3. If still capped, the missing tweets may be from accounts the auth'd user can't read (protected, blocked, deleted).
   Cross-check by `bird get /2/tweets/<id>` on a missing tweet to see the API's response.
4. If the tweet IS readable individually but `thread` still drops it, that's a bird bug — file at
   <https://github.com/brettdavies/bird/issues/new> with the thread id and `bird doctor` output.

## When to file a bug

A finding worth filing as `[skill]`-prefixed issue at <https://github.com/brettdavies/bird-skill/issues>:

- This bundle references a flag, command, or output that no longer matches the installed `bird`.
- A template's worked example is wrong.
- A reference doc contradicts the binary's own `--help` or `--examples`.

A finding worth filing against bird itself at <https://github.com/brettdavies/bird/issues>:

- A command returns the wrong exit code (e.g., a config error exiting 1 instead of 78).
- The JSON envelope is missing a field documented in `bird schema`.
- `bird doctor` reports `available: true` for a command that then fails with `kind: "auth"`.

Not worth a bug:

- "I wish bird wrapped xr's `media upload`." That's a bird feature request, not a skill issue.
- "This skill is too long." Open a discussion or PR against this bundle directly.

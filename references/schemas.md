# JSON Schema documents

bird ships embedded JSON Schema 2020-12 documents for every output shape. They are the **contract** with downstream
parsers, schema-validation tools, and the bird test suite (`tests/schema_parity.rs` locks runtime emitters to the
embedded docs).

## Listing and inspecting

```bash
bird schema --list --output json            # all schema names
bird schema --output json                   # default: success-envelope
bird schema <name> --output json            # one schema document
bird schema <name> --pretty                 # human-readable
```

Current schema names (verified against `bird 0.x` — re-run `bird schema --list` to confirm):

| Name               | Shape                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `success-envelope` | The universal `{"data": ..., "meta": ...}` envelope on stdout.                                                                                   |
| `error-envelope`   | The structured error envelope on stderr (`kind`, `exit_code`, optional `command`/`status`/`reason`). See [error-envelope.md](error-envelope.md). |
| `bookmarks`        | `bird bookmarks` response (paginated tweet array).                                                                                               |
| `search`           | `bird search` response (tweet array + ranking metadata).                                                                                         |
| `thread`           | `bird thread` response (root + descendants, ordered).                                                                                            |
| `profile`          | `bird profile` response (user object).                                                                                                           |
| `doctor`           | `bird doctor` report (xurl, auth, commands, cache).                                                                                              |
| `usage`            | `bird usage` response (api + local blocks). See [usage-and-cost.md](usage-and-cost.md).                                                          |
| `watchlist`        | `bird watchlist fetch` and `list` responses.                                                                                                     |
| `raw-get`          | `bird get` response when the path doesn't match a known entity shape.                                                                            |

## Pinning against `$id`

Every schema document carries a stable `$id`:

```text
https://bird.dev/schema/<name>-v1.json
```

When the document version bumps (breaking change), the `-v1` suffix increments. External consumers should pin against
the `$id` they tested against, not against `https://bird.dev/schema/<name>.json` without a version. The runtime emitter
and the embedded schema are tested for parity at every CI run — if they drift, CI fails before release.

## Validating a stored response

The fastest path is to feed bird's output into any JSON Schema validator that handles Draft 2020-12. With
[`check-jsonschema`](https://github.com/python-jsonschema/check-jsonschema):

```bash
bird schema bookmarks --output json > /tmp/bookmarks.schema.json
bird bookmarks --output json > /tmp/bookmarks.json

check-jsonschema --schemafile /tmp/bookmarks.schema.json /tmp/bookmarks.json
```

For ad-hoc field-shape probes, `jaq` is enough:

```bash
bird search "rustlang" --output json \
  | jaq -e '.data | length, .meta.next_cursor // null'
```

If you're holding a JSON file from an unknown source and need to know which bird schema it claims to be: the
`success-envelope` always wraps; the `data` shape is what matches one of the entity schemas above. Try each
`check-jsonschema` against the file until one passes.

## Schema vs the X API

bird's schemas describe **bird's** output, which wraps but does not mirror the raw X API response. Specifically:

- bird's envelope adds the `meta.next_cursor` field (unifying the X API's `pagination_token` / `next_token` variation
  across endpoints).
- bird may flatten or enrich fields when caching (e.g., expansions resolved into the entity).
- bird's `raw-get` schema is intentionally loose — it's the escape hatch when bird couldn't classify the response shape.

When you need the raw X API field semantics (e.g., the difference between `created_at` and `edit_history_tweet_ids`),
route to the `x-api` companion skill or `docs.x.com`.

## Adding schemas (producer-side note)

New bird subcommands ship a schema document under `bird/schema/<name>-v1.json` in the bird repo and a parity test in
`bird/tests/schema_parity.rs`. The `bird schema --list` output is derived from the directory at build time — if it's
listed there, it's available at runtime. There is no client-side schema registration; the bundle is closed at compile.

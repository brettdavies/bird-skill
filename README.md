# bird-skill

Agent skill for [`bird`](https://github.com/brettdavies/bird) — the X (Twitter) API CLI.

Bundles instructions, scripts, and references that teach an LLM agent how to drive `bird` effectively: authenticate via
`bird login`, read and write to the X API, manage watchlists, reconstruct conversation threads, and interpret usage and
rate limits.

## Status

Scaffolding only. The `SKILL.md` and supporting references land in subsequent PRs.

## Installation

Once the skill ships, install into Claude Code from this repo:

```sh
# placeholder — install instructions added when the skill is published
```

Requires `bird` v0.2.0 or newer on `PATH`:

```sh
brew install brettdavies/tap/bird
bird --version
```

## Layout

- `SKILL.md`: entrypoint Claude Code loads (forthcoming)
- `references/`: auxiliary docs the skill points the agent at (forthcoming)
- `scripts/`: the consumer-side `write-op-gate.sh`, plus maintainer release tooling (`release/`,
  `generate-changelog.py`, `sync-dev-after-release.sh`)
- `RELEASES.md`: how a change reaches users
- `AGENTS.md`: repo shape for agent contributors

## Contributing

Branching, PRs, and release cuts are documented in [`RELEASES.md`](RELEASES.md). The why is in
[`RELEASES-RATIONALE.md`](RELEASES-RATIONALE.md).

## License

Dual-licensed under either of:

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <https://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <https://opensource.org/licenses/MIT>)

at your option.

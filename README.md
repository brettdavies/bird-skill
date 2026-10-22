# bird-skill

Agent skill for [`bird`](https://github.com/brettdavies/bird), the X API CLI with a local entity store.

Bundles instructions, scripts, and references that teach an LLM agent how to drive `bird` effectively: check the
environment with `bird doctor`, keep repeated reads off the billed API with bird's cache modes, manage watchlists,
reconstruct conversation threads, read usage and cost, and put every write behind a dry run and confirmation.

## Installation

Install `bird`, then let it install the bundle into your agent host's skills directory:

```sh
brew install brettdavies/tap/bird
bird skill install claude_code      # or codex, cursor, factory, kiro, opencode; --all for every host
```

`bird skill update <host>` refreshes an install. [`getting-started.md`](getting-started.md) lists every host's path and
walks through a first session.

## Layout

- `SKILL.md`: the entry point the agent loads
- `getting-started.md`: the human quickstart
- `references/`: the docs the skill points the agent at, one topic per file
- `templates/`: task recipes (cached search, watchlist monitoring)
- `bin/check-update`: the update check `SKILL.md` runs first
- `scripts/`: the consumer-side `write-op-gate.sh`, plus maintainer release tooling (`release/`,
  `generate-changelog.py`, `sync-dev-after-release.sh`)
- `tests/`, `fixtures/`: the script tests and the stub `bird` they run against
- `evals/`: eval prompts for a fresh agent
- `RELEASES.md`: how a change reaches users
- `AGENTS.md`: repo shape for agent contributors

## Contributing

[`CONTRIBUTING.md`](CONTRIBUTING.md) has the workflow and house rules; branching, PRs, and release cuts are documented
in [`RELEASES.md`](RELEASES.md), and the why is in [`RELEASES-RATIONALE.md`](RELEASES-RATIONALE.md).

## License

Dual-licensed under either of:

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <https://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <https://opensource.org/licenses/MIT>)

at your option.

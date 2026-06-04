# Evals — end-to-end discovery and workflow tests

Each `eval-*.md` in this directory is a **self-contained prompt** for a fresh agent. The agent has no prior context; the
prompt is the only briefing.

Eval prompts deliberately:

- Never name the skill in the body (the trigger keywords in the frontmatter description must do the discovery work).
- Never name the underlying tool by exact verb when a user-task phrasing would do.
- Specify a fresh workdir (`/tmp/bird-eval-<ts>/`) so artifacts don't collide between runs.
- List required artifacts on a known path so a reviewer can verify completeness without re-running the agent.
- Numbered success criteria scored 0-10.
- Include a "document dead-ends" rule so the agent surfaces what it tried and what didn't work.

**Mutating evals** — those that end in a destructive call (live `bird tweet`, `bird like`, `bird delete`, etc.) require
a `--dry-run` execution gate. The eval prompt asks the agent to capture stdout+stderr+exit of the planned command and
caps the self-assessment score at 5 if the artifact is missing. This protects shared state (real X account, live API
spend) across runs.

## Cataloged evals

| Eval                                                                       | What it tests                                                                                                                                                                                                                 | Mutating? |
| -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| [eval-01-doctor-and-cached-search.md](eval-01-doctor-and-cached-search.md) | Discovery from trigger keywords; environment check via diagnostics; cached search workflow with `--cache-only` replay; forced escalation when a question crosses into auth/scope territory the docs deliberately don't cover. | no        |

## Where artifacts land

Each eval's workdir is `/tmp/bird-eval-<eval-name>-<ts>/`. The directory is **never committed**; it's reproducible from
the prompt. Each eval lists the artifacts it expects there (FINAL-REPORT.md, dryrun-output.txt if mutating, etc.).

## Running an eval

The eval prompt is the entire input. Open a fresh Claude Code session (or other host), paste the prompt body, let the
agent work to completion. Review the workdir artifacts against the success criteria in the prompt.

## Leak-grep self-match defense

When an eval recipe scans the workdir for a sensitive sentinel, the recipe must:

1. Exclude the eval's own report files: `rg --glob '!FINAL-REPORT.md' --glob '!EVAL.md' ...`
2. Split the needle in the recipe source so the recipe text itself doesn't carry a contiguous match. For bird, the most
   common sensitive sentinel would be a leaked X API token or bearer prefix — the recipe must construct the needle from
   pieces (e.g., `NEEDLE='AAAA'$'A''ABBBB'`) rather than write the full string.

bird tokens live in xurl's `~/.xurl` store, not in bird's config. The most likely accidental leak inside an eval would
be the **username** of the active account, which appears in success envelopes. The eval prompt should anonymize that
before publishing artifacts.

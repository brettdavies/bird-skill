# Evals

Self-contained evaluation prompts for the consumer-side behavior of this skill. Each eval dispatches to a fresh agent
session with no prior context, hands it the prompt body, and grades the resulting artifacts against numbered success
criteria.

**Discovery is part of every eval.** No prompt body names the skill, and none names a bird verb where a user-task
phrasing would do. The description in `SKILL.md`'s frontmatter is the only signal the agent has that this skill applies.
If a fresh agent can't find this skill from the prompt, that's a finding; re-tune the description's trigger keywords.

## Catalog

| Eval                                                                       | Tests                                                                                                   | Mutating? | Regression-tests | Re-run when                                                                           |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | --------- | ---------------- | ------------------------------------------------------------------------------------- |
| [eval-01-doctor-and-cached-search.md](eval-01-doctor-and-cached-search.md) | Discovery; environment check via diagnostics; cached search with a store-only replay; forced escalation | No        | none (inaugural) | `SKILL.md` description, `error-envelope.md`, `cache-modes.md`, `escalation.md` change |
| [eval-02-compose-reply-dry-run.md](eval-02-compose-reply-dry-run.md)       | Discovery; `scripts/write-op-gate.sh` selection; DO-NOT-PUBLISH gate                                    | Yes       | F1 F2            | `write-op-gate.sh`, `scripts/README.md`, `error-envelope.md` change                   |
| [eval-03-watchlist-monitor.md](eval-03-watchlist-monitor.md)               | Discovery; watchlist setup and clean-up; cron-safe flags; one-pass cost discipline                      | No        | none             | `templates/watchlist-monitor.md`, `agent-flags.md`, `usage-and-cost.md` change        |
| [eval-04-thread-offline-analysis.md](eval-04-thread-offline-analysis.md)   | Discovery; thread reconstruction; store-only replay; the usage ledger as proof of no billed call        | No        | none             | `cache-modes.md`, `usage-and-cost.md`, or the thread routing row in `SKILL.md` change |

## Fixes under regression test

An eval that carries a "Regression-test prior fixes" section names entries from this list by id. The agent classifies
each named entry as `worked` / `regressed` / `not-touched` in `FINAL-REPORT.md`; any `regressed` is a blocking finding.
Add an entry here when a bundle fix lands that a future eval could silently undo; retire one when the surface it guards
is gone.

| Id  | Where                                           | Expected behavior                                                                                                                               |
| --- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| F1  | `scripts/write-op-gate.sh`; `scripts/README.md` | The confirmed live call carries `--force`, so a headless `--yes` call reaches the API instead of failing at exit 2 with `requires-confirmation` |
| F2  | `scripts/write-op-gate.sh`                      | The dry run's stderr goes to a private `mktemp` file the gate removes; nothing is written to a fixed path under `/tmp`                          |

## Workdir convention

Each eval creates a fresh workdir at `/tmp/bird-eval-<N>-$(date +%s)/` and treats it as CWD (eval-01 names its own,
`/tmp/bird-eval-doctor-and-cached-search-<ts>/`). Artifacts land there. Workdir contents are never committed;
reproducibility comes from re-running the prompt against a fresh agent.

## Grading

Each eval ships numbered success criteria, each scored independently 0–10. The eval score is the average, rounded to one
decimal. Three categories of artifacts are inspected:

1. **Required files in workdir** (named in the eval's `## Required artifacts` section). Missing one is an automatic 0 on
   that criterion.
2. **`FINAL-REPORT.md` content**: the agent's reflective summary. Required sections vary per eval.
3. **Side effects**: for mutating evals (eval-02), evidence that no live mutation was attempted. See the eval's
   `## Dry-run execution gate` section; a missing dry-run capture caps the score at 5.

Every live read is billed per object under the X API's pay-per-use pricing, so each eval states its call budget and
scores cost discipline where it makes live calls.

## Running an eval

Dispatch a fresh agent session with the eval prompt body as the user message. No prior context. Where a prompt carries a
`<POST_ID>` placeholder, replace it with a real post id first. After the agent finishes, walk the workdir and
`FINAL-REPORT.md` to fill in the score sheet.

A graded round produces an `evals/round-<date>.md` summary that classifies each fix id above (worked / regressed /
not-touched) and lists new findings worth fixing in the bundle. That file is the input the next round regression-tests
against.

## Iteration loop

Evals are not a one-time gate. The loop is: run → grade → fix bundle issues the eval found → re-run later. Each round's
findings get an id in the table above so a fix that silently broke is caught immediately.

The convention these prompts follow (the properties of a good eval prompt, the dry-run gate, the leak-grep defense) is
the `evals.md` reference of the `create-agent-skills` skill in the `brettdavies/agent-skills` repository.

## Leak-grep self-match defense

When an eval recipe scans the workdir for a sensitive sentinel, the recipe must:

1. Exclude the eval's own report files: `rg --glob '!FINAL-REPORT.md' --glob '!EVAL.md' ...`
2. Split the needle in the recipe source so the recipe text itself doesn't carry a contiguous match. For bird, the most
   common sensitive sentinel would be a leaked X API token or bearer prefix; the recipe constructs the needle from
   pieces (e.g., `NEEDLE='AAAA'$'A''ABBBB'`) rather than writing the full string.

bird stores no tokens itself; they live in the `~/.xurl` token store. The most likely accidental leak inside an eval is
the **username** of the active account, which appears in success envelopes. Anonymize it before publishing artifacts.

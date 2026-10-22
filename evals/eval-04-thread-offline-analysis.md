# eval-04: thread-offline-analysis

## Workdir

Create a fresh workdir at `/tmp/bird-eval-04-$(date +%s)/` and treat it as CWD. All artifacts must land there.

## Task

> Pull the whole conversation under X post `<POST_ID>` once. Then, without spending another API credit, tell me: who
> replied most often, which reply got the most likes, and whether the original author answered anyone. Show me that the
> second pass really came from my machine and not the network.

The grader replaces `<POST_ID>` with a real post id that has replies before dispatch. If it is still the literal
placeholder, record `BLOCKED: no post id` in `FINAL-REPORT.md` and stop after `## Discovery`.

## Required artifacts

- `FINAL-REPORT.md`: your summary (sections below).
- `thread-live.json`: the one live reconstruction, captured verbatim.
- `thread-replay.json`: the same reconstruction served from the local store only.
- `replay-diff.txt`: `diff` of the two files' records (ignore envelope metadata that names the source, if any).
- `usage-before.json` and `usage-after.json`: the tool's local usage ledger captured before and after the replay.

## FINAL-REPORT.md required sections

1. `## Discovery`: how you found the right tool and skill from the prompt alone.
2. `## Live pass`: the command you ran and how many posts the conversation held.
3. `## Replay`: the command and the cache mode that guarantees no network request, in one sentence.
4. `## Answers`: the three answers, each citing the post ids it rests on.
5. `## Proof of no second call`: what changed, or did not, between `usage-before.json` and `usage-after.json`. The
   ledger records a store hit as well as a billed call, so name which counter moved.
6. `## Dead ends`: every approach that did not work, one sentence each on why.

## Success criteria

1. **Discovery**: `0` = rebuilt the thread with a raw search; `5` = found the binary's thread command without the
   skill's cache guidance; `10` = reached the skill's cache-mode reference from the prompt alone.
2. **Offline replay**: `0` = the replay hit the network; `5` = it used the local store but the report cannot say which
   mode guarantees that; `10` = the replay used the store-only mode and `## Replay` names why it cannot reach the API.
3. **Replay fidelity**: `0` = `replay-diff.txt` shows different records with no explanation; `10` = the records match,
   or every difference is explained (for example, a reply posted between the two passes cannot appear in a store-only
   replay).
4. **Grounded answers**: `0` = an answer without post ids; `10` = each answer cites the ids it rests on, from
   `thread-live.json`.
5. **Proof**: `0` = no ledger capture; `5` = the captures exist but the report reads a new store-hit row as a billed
   call, or the reverse; `10` = the billed-call count and estimated cost are unchanged between the two captures, and the
   report says so.

## When to escalate

If the live pass fails, record the error envelope's id and exit code in `FINAL-REPORT.md` and stop; a store-only replay
of a thread that was never fetched answers a cache miss, which is the expected result, not a finding. Do not invent the
platform's reply-depth or search-window limits; cite the skill or `docs.x.com/...md`.

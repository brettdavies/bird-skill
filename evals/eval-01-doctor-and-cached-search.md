# Eval — environment check, cached search, forced escalation

You are a fresh agent. Work entirely from the prompt below — do not assume prior context.

## Task

The user is starting a session and has these three asks, in order:

1. **"Tell me whether my X (Twitter) tooling is ready to use, and if not, what's broken."**
2. **"Pull the top 5 most-liked recent tweets matching `rustlang has:links -is:retweet`, then re-run the same query
   against local data only without spending API credits, and confirm both passes return the same record set."**
3. **"What OAuth scope do I need granted to send a direct message via this tooling, and why doesn't the answer live in
   the current skill bundle?"**

Treat each ask as sequential. Capture your work as you go in the workdir below.

## Workdir

```text
/tmp/bird-eval-doctor-and-cached-search-<ts>/
```

`<ts>` = current Unix timestamp. Create the directory at the start. Every artifact lands here. Do not commit it; the
prompt is the source of truth.

## Required artifacts

| File                  | What it must contain                                                                                                   |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `FINAL-REPORT.md`     | One section per task ask; numbered success-criteria self-score 0-10; explicit "document dead-ends" subsection.         |
| `doctor.json`         | Output of the environment-health check, captured verbatim.                                                             |
| `search-fresh.jsonl`  | Streaming-JSONL output of the live search.                                                                             |
| `search-replay.jsonl` | Streaming-JSONL output of the same query, served from local cache only.                                                |
| `replay-diff.txt`     | `diff` of the two JSONL files; should be empty.                                                                        |
| `escalation-trail.md` | Where you looked for the OAuth-scope answer, in order, with one-line notes on what each source did or did not provide. |

## Success criteria

1. **Discovery** — you reached the right tool for task 1 from the user's phrasing alone (no skill name in the prompt).
   Score 10 if you found and used the right diagnostics command without the user pointing you at it; 0 if you
   freelanced.
2. **Environment health** — `doctor.json` captures the full envelope (xurl path/version, auth state, per-command
   availability, cache health). If the environment is unhealthy, FINAL-REPORT section 1 names the specific failing key
   and the fix.
3. **Cached replay correctness** — `replay-diff.txt` is empty AND you can explain WHY in one sentence (which cache mode
   gives you that guarantee). Score 10 if both pass; halve for a non-empty diff or a vague explanation.
4. **Cost discipline** — the second pass made **zero** API calls. Verify by capturing local-only usage before/after and
   noting the call count is unchanged. Score 0 if you re-ran the live query for the replay.
5. **Forced escalation** — task 3 asks about an OAuth scope. The current bird skill deliberately does not own this
   information (it lives in a companion skill or the X docs). Your `escalation-trail.md` must show: (a) which bird
   command/doc you tried first; (b) why it didn't answer; (c) the correct authoritative source you landed on (companion
   skill name, or a `docs.x.com/.../<page>.md` URL). Score 10 if you reached an authoritative answer; 5 if you guessed a
   plausible scope name without source attribution; 0 if you invented one.

## Document dead-ends

A subsection at the end of `FINAL-REPORT.md` titled `## Dead-ends`. List every approach you tried that did not work,
with one sentence per item explaining why it failed. The goal is to surface friction the skill bundle should fix
(missing trigger keywords, unclear routing, broken examples).

## Non-goals

- You do **not** need to authenticate if `auth.authenticated: false`. If task 1 surfaces an auth gap, report it in
  FINAL-REPORT section 1 and proceed to tasks 2-3 only if you can do so against cached data. Do not interactively run
  any browser-based auth.
- You do **not** need to send any write op. This eval has no mutating step.

## Self-assessment

End `FINAL-REPORT.md` with a `## Score` block: one line per criterion (1 through 5 above), a per-criterion 0-10, and a
weighted total. Be honest. If criterion 5 was skipped because the answer was inside the bundle after all, score it 10
with a note that the trigger keyword surprised you (and update `escalation-trail.md` to show the path).

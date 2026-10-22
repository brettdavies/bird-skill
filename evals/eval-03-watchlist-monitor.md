# eval-03: watchlist-monitor

## Workdir

Create a fresh workdir at `/tmp/bird-eval-03-$(date +%s)/` and treat it as CWD. All artifacts must land there.

## Task

> I want to keep an eye on what `@XDevelopers` and `@rustlang` post without checking their profiles by hand. Set my X
> tooling up to track them, tell me what each has posted recently, and give me a script I can drop into cron to run the
> same check hourly without it ever hanging on a prompt. When you're done, leave my tracked-accounts list exactly as you
> found it; I'll add them myself once I've read your script.

Every read here is billed per object returned. Keep the live check to one pass over the two accounts and the smallest
page the tooling allows.

## Required artifacts

- `FINAL-REPORT.md`: your summary (sections below).
- `list-before.json`: the tracked-accounts list as you found it, captured before any change.
- `list-after.json`: the same list after your clean-up.
- `fetch.json`: the output of the one live activity check, captured verbatim.
- `cron-check.sh`: the hourly script.

## FINAL-REPORT.md required sections

1. `## Discovery`: how you found the right tool and skill from the prompt alone.
2. `## Setup`: the commands that added and later removed the two accounts, and where the tool keeps the list.
3. `## Recent activity`: one paragraph per account, grounded in `fetch.json`. Name any account the check could not read
   and the error it reported.
4. `## Cron script`: what each setting in `cron-check.sh` guards against, including an expired credential mid-loop.
5. `## Cost`: the number of live calls you made and how you kept it at one pass.
6. `## Dead ends`: every approach that did not work, one sentence each on why.

## Success criteria

1. **Discovery**: `0` = searched each profile by hand; `5` = found the binary's tracking feature without the skill's
   template; `10` = reached the skill's watchlist template from the prompt alone.
2. **List restored**: `0` = `list-after.json` differs from `list-before.json`; `10` = the two are identical (an account
   that was already tracked stays tracked).
3. **Grounded report**: `0` = activity described without `fetch.json` behind it; `5` = partly grounded; `10` = every
   claim traces to a record in `fetch.json`, and a per-account error, if any, is named rather than dropped.
4. **Cron safety**: `0` = the script can block on a prompt or a browser; `5` = it is non-interactive but parses text
   output; `10` = it runs non-interactive with JSON output and quiet stderr, and it exits on an auth failure (the auth
   exit code) with a log line rather than retrying blind.
5. **Cost discipline**: `0` = more than one live pass, or a search used in place of the tracking check; `10` = one pass,
   counted in `## Cost`.

## When to escalate

If the tracking check fails on authentication, record the envelope (its error id and exit code) in `FINAL-REPORT.md`, do
not start a browser sign-in, and still deliver `cron-check.sh` and the restored list. Do not invent rate limits or
per-object prices; the skill's usage reference and the platform's docs (`docs.x.com/...md`) own those numbers.

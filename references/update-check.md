# Update check

`bin/check-update` compares this bundle's `VERSION` against the `VERSION` on `main` on GitHub. Its exit code is always
`0`: network failures, a missing or malformed `VERSION`, and a disabled check all leave stdout empty. `SKILL.md` names
the agent-visible step; this file is the script's contract.

## Output

| Stdout                               | Meaning                                                                             |
| ------------------------------------ | ----------------------------------------------------------------------------------- |
| (empty)                              | Up to date, snoozed, disabled, or the check was skipped (no `VERSION`, no network). |
| `UPGRADE_AVAILABLE <local> <remote>` | A newer bundle is on `main`. Ask the user as below.                                 |

## Ask the user

> The bird skill **v{remote}** is available (you're on v{local}). Update now?

Three options:

- **"Yes, update now"**: run `bird skill update <host>` for the host this bundle is installed under (`claude_code` for
  `~/.claude/skills/bird`; [references/skill-install.md](skill-install.md) lists every host and path). It removes the
  install directory and clones the bundle fresh. Surface its error envelope verbatim if it fails, and stop.
- **"Not now"**: write `$HOME/.cache/bird-skill/update-snoozed` as `<remote> <level> <epoch>`, where `<level>` is `1`
  (remind in 24 hours), `2` (48 hours), or `3` (7 days), one level higher each time the user defers. A newer remote
  version resets the snooze. Tell the user when the next reminder comes.
- **"Never ask again"**: `touch $HOME/.cache/bird-skill/disabled`, and tell the user that removing that file turns the
  check back on.

## State directory

`$HOME/.cache/bird-skill/` holds `last-update-check` (the cached answer: `UP_TO_DATE <version>` for 60 minutes,
`UPGRADE_AVAILABLE <local> <remote>` for 12 hours), `update-snoozed`, and `disabled`. The script creates the directory
the first time it fetches the remote `VERSION`.

`BIRD_SKILL_DIR`, `BIRD_SKILL_STATE_DIR`, and `BIRD_SKILL_REMOTE_URL` override the install root, the state directory,
and the remote URL; `tests/run.sh` uses them to run the script without the network or the real cache.

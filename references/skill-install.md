# `bird skill install` — self-bootstrap

bird ships its own skill bundle installer. `bird skill install <host>` runs a hardened `git clone --depth 1` of this
repository ([brettdavies/bird-skill](https://github.com/brettdavies/bird-skill)) into the host's canonical skills
directory. `bird skill update <host>` removes the destination and re-clones.

## Supported hosts

| Host          | Destination                      |
| ------------- | -------------------------------- |
| `claude_code` | `~/.claude/skills/bird`          |
| `codex`       | `~/.codex/skills/bird`           |
| `cursor`      | `~/.cursor/skills/bird`          |
| `factory`     | `~/.factory/skills/bird`         |
| `kiro`        | `~/.kiro/skills/bird`            |
| `opencode`    | `~/.config/opencode/skills/bird` |

The list is the single source of truth in bird's `src/skill_install/skill.json`; `build.rs` codegens the host enum at
build time, so `bird skill install --help` always lists exactly what the binary supports.

## Usage

```bash
bird skill install claude_code              # clone into ~/.claude/skills/bird
bird skill install claude_code --dry-run    # print the planned `git clone` without spawning git
bird skill install --all                    # install into every supported host
bird skill install --all --output json      # machine-readable per-host report
bird skill update claude_code               # remove destination + re-clone (refresh)
```

Without `<host>` or `--all`, `bird skill install` returns exit 2 (`requires-confirmation`-shaped envelope with `reason:
"missing-host"`) and lists the supported hosts. Pass one or `--all` to proceed.

## Envelope shape

Under `--output json`:

```json
{
  "data": {
    "action": "install | update",
    "host": "claude_code",
    "install_dir": "/home/user/.claude/skills/bird",
    "command_preview": "git ... clone --depth 1 https://github.com/brettdavies/bird-skill /home/user/.claude/skills/bird",
    "destination_status": "missing | exists | overwritten",
    "status": "ok | dry_run | error",
    "exit_code": 0,
    "reason": "<slug, optional>"
  },
  "meta": {}
}
```

`--dry-run` returns `status: "dry_run"` and never spawns git. `--all` returns one envelope per host, separated by a
newline when `--output jsonl`.

## Why the clone is hardened

The clone strips and pins git's environment so the install can't be hijacked by a stale `~/.gitconfig`, an SSH agent
substitution, or a redirect to a different repo:

- `-c credential.helper=` — disables any credential helper.
- `-c core.askPass=` — disables interactive password prompts.
- `-c protocol.allow=never -c protocol.https.allow=always` — HTTPS-only; refuses git://, ssh://, file://.
- `-c http.followRedirects=false` — refuses HTTP redirects.
- `GIT_SSH`, `GIT_SSH_COMMAND`, `GIT_PROXY_COMMAND`, `GIT_ASKPASS`, `GIT_EXEC_PATH` are stripped from the spawn env.
- `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_SYSTEM=/dev/null`, `GIT_TERMINAL_PROMPT=0` — block user-config rewriting
  and terminal prompts.

The pattern mirrors `xurl-rs`'s `xr skill install` and `agentnative-cli`'s skill installer. Trust comes from the
hardened clone; the user does not need to vet their git config before running.

## When to use `update` vs `install`

- **`install`** when the destination doesn't exist. Refuses to overwrite a pre-existing directory unless `--force` is
  passed (which the install verb does not accept by default — use `update` instead).
- **`update`** when the destination already exists. Removes the destination, then re-clones. This is the right verb to
  refresh against a new release of this bundle.

There is no "git pull" mode — `update` is always a full re-clone. The trade-off: simpler, safer, no merge-conflict
recovery. The bundle is small (markdown + tiny shell scripts); re-clone cost is negligible.

## Verifying after install

```bash
ls ~/.claude/skills/bird/SKILL.md           # exists
bird skill install claude_code --output json | jaq '.data.destination_status'   # "exists"
```

The skill is now in the host's discovery path. Reload the host (Claude Code: new session; Codex/Cursor/etc per their
docs) so it picks up the new skill.

## Companion-skill install reminders

Bird's value compounds with two companion skills. Their installers are independent:

- **`xurl-rs`** — `xr skill install claude_code` (after `brew install brettdavies/tap/xurl-rs`). Same mechanic.
- **`x-api`** — currently distributed manually; check <https://github.com/brettdavies/x-api-skill> for the canonical
  install path. `user-invocable: false`, so it auto-loads when bird or xr is in context.

Pre-flight every new shell with `bird doctor`, then `xr auth status`, then a smoke `bird me --output json` — that's the
shortest path to "I know all three layers are alive."

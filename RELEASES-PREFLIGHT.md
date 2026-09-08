# Pre-release verification: `bird-skill`

Operational pre-flight checklist. Runs **before** step 1 of
[`RELEASES.md` § Releasing dev to main](./RELEASES.md#releasing-dev-to-main). Gates the cut of the `release/v<version>`
branch, not the daily dev integration. Each box is an explicit go/no-go. If any item is unchecked or red, hold the
release.

CI catches mechanical regressions inside this repo (markdown lint). This checklist covers what CI structurally can't:

- Breaking changes to a contract that downstream consumers must adapt to (bundle layout, script flags, the `bird`
  version the skill assumes).
- Real-world behavior against the `bird` binary and the live install path.
- Distribution paths that only exercise on real artifacts (`git clone` to a real install destination).
- Cross-repo sequencing where releasing here before a sibling repo is ready breaks downstreams.

Post-tag verification (tag push, GitHub Release, consumer re-clone, backport) lives in
[`RELEASES-POSTFLIGHT.md`](./RELEASES-POSTFLIGHT.md). The tag push happens AFTER the release-branch cut and the
PR-to-main merge, so verification of the published release is post-flight, not pre-flight.

## Quick start: run the automated gate

`bird-skill` vendors no `preflight.sh`; the bundle has no binary, no lockfile, and no live surface for a script to
exercise, so the checklist below is walked by hand. The one automated gate is branch drift:

```bash
scripts/release/drift.sh
```

The rest of this checklist is walked by hand, in order. Branch drift comes first, since nothing else matters while
`main` holds changes `dev` never received.

## Establish the surface

Everything below assumes you know what's changing. Run this first.

```bash
LAST_TAG=$(git tag --sort=-version:refname | head -n 1)
git log "$LAST_TAG..dev" --oneline                              # commits going out
git diff "$LAST_TAG..dev" --stat                                # file-level scope
git log "$LAST_TAG..dev" --grep '^[a-z]\+\(([^)]*)\)\?!:' --oneline   # Conventional-Commits breaking markers, scoped or not
```

On a repo with no tags yet, or whose lineage is squash-only so no tag is an ancestor of `dev`, the surface is
`origin/main..origin/dev` instead of `$LAST_TAG..dev`.

Every `!:` commit drives the major-version decision and gets a row in the release's `### Breaking changes` section.

## Checklist

### Branch drift (main ahead of dev)

Driven by `scripts/release/drift.sh`.

Security PRs, hotfixes, and config edits land on `main` first. The release branch is cut from `main` and then takes
`dev`'s changes, so anything `main` holds that `dev` never received is reverted by the release or collides with it, and
Dependabot raises the same fix again.

- [ ] The previous release's bookkeeping reached `dev` (gate 0 fails when it never did; run
      `scripts/sync-dev-after-release.sh v<version>`, merge its PR, and rerun).
- [ ] Every commit on `main` since the last release has its changes on `dev` (gate 1 lists the ones that do not, as
      `differs` or `missing`). Backport them by PR into `dev` first, merge, and rerun.
- [ ] `.github/` is identical on both branches (gate 2). A difference either way is a config change that only reached
      one branch.
- [ ] No lockfile package resolves newer on `main` than on `dev` (gate 3). This repo carries no lockfile, so the gate
      SKIPs; it becomes live the day one is added.
- [ ] `dev`-newer files are the routine changes this release ships; the gate counts them and does not list them.

### Cross-repo blast radius

- [ ] **Contract diff.** Diff every consumer-facing contract (bundle layout, `SKILL.md` frontmatter, `write-op-gate.sh`
  flags and exit codes, `references/` file names `SKILL.md` links to) between `$LAST_TAG` and `dev`. Every field
  renamed / added / removed / shape-changed becomes a row in the release's `### Breaking changes` (consumers
  feature-detect from this list).
- [ ] **Downstream consumers ready.** The `bird` binary's `skill install` points at this repo's `main`; a bundle layout
  change that moves `SKILL.md` or `scripts/` breaks every host's discovery path. If `bird` is not ready, hold the tag.
- [ ] **Version-cross references.** The `bird` version pinned in `README.md` (`Requires bird v<MIN>`) matches the
  surface the skill teaches. A new `bird` flag documented in `SKILL.md` or `references/` bumps the pin in lockstep.
- [ ] **Install-path destinations.** Every install URL or path the release will resolve to (the six host destinations
  in `references/skill-install.md`) actually exists on a `bird` that ships today.

### Real-world smoke

CI exercises one shape; manual probes cover the rest. Pick fresh targets each release.

- [ ] **Skill bundle: install + load.** `bird skill install <host>` for each host slug, against a clean per-host
  destination directory. Confirms the hardened `git clone` reaches the live bundle repo, not just a test fixture.
- [ ] **`write-op-gate.sh` end-to-end.** Drive one dry-run reject (exit 1), one non-TTY refusal without `--yes` (exit
  3), one forbidden pass-through flag (exit 2), and one live path with `--yes` against a safe target. Confirms the exit
  code table in `scripts/README.md` still matches the script.
- [ ] **Regression markers.** Any bug fixed in this release: re-run against a target that previously demonstrated the
  bug. Confirms the fix lands in the release artifact, not just on `dev`.

### Distribution and install paths

The release is a `git clone --depth 1` of `main`. None of this runs in CI.

- [ ] **Bundle install probe.** `git clone --depth 1 https://github.com/brettdavies/bird-skill /tmp/bird-skill-probe`
  from the install URL to a fresh directory. Confirms the install lands the expected files at the expected paths
  (`SKILL.md`, `references/`, `scripts/write-op-gate.sh`, `templates/`).
- [ ] **Prior-release probe.** `bird skill update <host>` on a machine that installed the previous release. Confirms
  the remove-and-reclone path still works when the destination already exists.

### Release mechanics sanity

These items duplicate steps in `RELEASES.md` deliberately: easy to skip, expensive to recover from. Confirm explicitly.

- [ ] **`VERSION` bumped** to the new tag value (`v<X.Y.Z>` minus the leading `v`; plain text, one line).
- [ ] **Every merged PR since `$LAST_TAG` has a non-empty `## Changelog` section.** Spot-check via:

  ```bash
  gh pr list --base dev --state merged \
    --search "merged:>$(git log -1 --format=%aI $LAST_TAG)"
  # Then for each PR:
  gh pr view <num> --json body
  ```

- [ ] **Diff-A verification before commit.** On the staged overlay, `git diff --cached --name-only origin/dev` filtered
  by the guarded set (not all of `docs/`, since a directory that ships to `main` would hide a missed path) and the
  version files prints nothing. Anything else printed is a mistake in the overlay.
- [ ] **Leak check before pushing the release branch.** No guarded path may surface in the diff vs `origin/main`. The
  set resolves from `.github/workflows/guard-main-docs.yml` via `scripts/release/guarded-paths.sh`; never restate the
  pattern inline.

  ```bash
  GUARDED="$(scripts/release/guarded-paths.sh)"
  git diff origin/main..HEAD --name-only | grep -E "$GUARDED" && echo "LEAKED: reset and redo" || echo "(clean)"
  ```

- [ ] **Every doc this release adds to `main` is meant to ship.** The leak check is blind to a category nobody
  registered. `git diff origin/main..HEAD --diff-filter=A --name-only | grep -E '(^docs/|\.md$)' | grep -Ev "$GUARDED"`
  lists the unguarded additions; each one needs a reason to ship, or it gets registered in the workflow's
  `extra_paths` and removed from the branch.
- [ ] **`CHANGELOG.md` versioned section** has no `[Unreleased]` placeholder and matches the bumped version.

### Local gates and shipped-script smoke

bird-skill is a docs-only bundle. There is no `cargo test` to run; the local gates are markdown lint, script parse, and
shipped-script smoke tests. Run every box on the staged `release/v<X.Y.Z>` branch before opening the PR to `main`. CI
runs the same lint job, but the script smoke is not in CI and is the most likely thing to regress silently.

- [ ] **Markdown lint clean across the whole tree.** CI runs this on the PR, but rerun locally on the release branch to
  fail fast:

  ```bash
  bunx markdownlint-cli2 "**/*.md"            # must report 0 errors
  ```

- [ ] **Every shipped shell script parses and lints.** Catches the kind of `unbalanced quote` / missing `fi` that only
  surfaces when the script actually runs on the post-tag path:

  ```bash
  for f in scripts/*.sh scripts/release/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
  shellcheck --severity=warning scripts/*.sh scripts/release/*.sh
  shfmt -i 2 -ci -bn -d scripts/release/*.sh scripts/sync-dev-after-release.sh
  ```

- [ ] **`scripts/generate-changelog.py` smoke.** On the staged release branch (so the branch-name version extraction has
  something to match):

  ```bash
  scripts/generate-changelog.py --print-tag            # prints v<X.Y.Z> from the branch name
  scripts/generate-changelog.py --check                # exit 0 = CHANGELOG.md has a versioned section
  scripts/generate-changelog.py --dry-run --from-dev-prs   # exit 0 = no drift between PR bodies and CHANGELOG.md
  ```

  Drift (exit 1) means a merged PR's `## Changelog` body diverges from what got written. Resolve before tagging; once
  the tag pushes, the bad CHANGELOG is in the release notes.

- [ ] **`scripts/sync-dev-after-release.sh` smoke.** The script only runs post-tag (it gates on tag existence + GitHub
  Release presence), so pre-cut smoke is limited to syntax + a read of the prerequisites it checks:

  ```bash
  bash -n scripts/sync-dev-after-release.sh
  grep -E '^(# Verify|# Cut)' scripts/sync-dev-after-release.sh   # confirms the guard lines still exist
  ```

  Reserve the actual run for after the tag pushes ([`RELEASES-POSTFLIGHT.md`](./RELEASES-POSTFLIGHT.md) covers it).

- [ ] **`bird --version` ≥ the minimum pinned in `README.md`.** The skill teaches an agent how to drive `bird`. If
  `README.md` documents `Requires bird v<MIN>`, the locally-installed `bird` must satisfy it before shipping. Otherwise
  users following the install instructions get a tool that mismatches the skill's expectations.

  ```bash
  bird --version
  rg '^Requires `bird` v' README.md                  # pin lives here; bump in lockstep with skill content
  ```

- [ ] **`SKILL.md` references resolve.** Every `references/<file>` or `scripts/<file>` mentioned in `SKILL.md`
  physically exists in the working tree at the path the file claims.

  ```bash
  rg -oN '\((?:\./)?(references|scripts)/[^)]+\)' SKILL.md \
    | sed -E 's/.*\(\.?\/?//; s/\)$//' \
    | xargs -I{} test -e {} || echo "broken ref"
  ```

### Post-tag verification

Lives in [`RELEASES-POSTFLIGHT.md`](./RELEASES-POSTFLIGHT.md) because tagging happens **after** the release-branch cut
and PR-to-main merge, so verification of the published release (tag, GitHub Release, consumer re-clone, backport) is
post-flight, not pre-flight.

## Related docs

- [`RELEASES-POSTFLIGHT.md`](./RELEASES-POSTFLIGHT.md): runs AFTER the tag push to verify the published release.
- [`RELEASES.md`](./RELEASES.md): operational runbook this checklist gates.
- [`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md): release-flow rationale.

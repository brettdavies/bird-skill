# Releasing `bird-skill`

Operational runbook. Rationale lives in [`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md). Pre-cut go/no-go checklist
lives in [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md); post-tag verification lives in
[`RELEASES-POSTFLIGHT.md`](./RELEASES-POSTFLIGHT.md).

```text
feature branch → PR to dev (squash merge)
              → overlay onto a release/* branch cut from main
              → PR to main (squash merge)
              → annotated tag + GitHub Release
```

Direct commits to `dev` or `main` are not permitted: every change has a PR number in its squash commit message.

## Branches

| Branch                                 | Role                                    | Lifetime                                    | Protection                                   |
| -------------------------------------- | --------------------------------------- | ------------------------------------------- | -------------------------------------------- |
| `main`                                 | Production. Only release commits.       | Forever.                                    | `.github/rulesets/ruleset-protect-main.json` |
| `dev`                                  | Integration. All feature PRs land here. | Forever. Never delete.                      | `.github/rulesets/ruleset-protect-dev.json`  |
| `feat/*`, `fix/*`, `chore/*`, `docs/*` | Feature work.                           | One PR's worth. Auto-deleted on merge.      | None. Squash into dev freely.                |
| `release/*`                            | Head of a dev → main PR.                | One release's worth. Auto-deleted on merge. | None.                                        |

`dev` is a **forever branch**. Never delete it locally or remotely, even after a `release/* → main` merge. The next
release cycle reuses the same `dev`. The repo's `deleteBranchOnMerge: true` setting doesn't touch `dev` as long as `dev`
is never the head of a PR; the short-lived `release/*` head is what keeps the setting compatible with a forever
integration branch.

→ Rationale: [`RELEASES-RATIONALE.md` § Branching model](./RELEASES-RATIONALE.md#branching-model).

## Daily development (feature → dev)

```bash
git checkout dev && git pull
git checkout -b feat/short-description
# ... work ...
git push -u origin feat/short-description
gh pr create --base dev --title "feat(scope): what changed"
# CI passes → squash-merge (PR_BODY becomes the dev commit message)
```

- **Commit style**: [Conventional Commits](https://www.conventionalcommits.org/).
- **PR body**: follow `.github/pull_request_template.md`. See [§ PR body](#pr-body).

### Dev-direct exception

Paths that live only on `dev` and never ship to `main` can be committed directly to `dev` without a feature branch or
PR. The `guard-main-docs` workflow blocks them from `main` PRs regardless. The exception applies to:

- Engineering docs: `docs/brainstorms/`, `docs/ideation/`, `docs/plans/`, `docs/research/`, `docs/reviews/`,
  `docs/solutions/`, and anything under `.context/`.

The standard feature → PR → squash-merge flow remains required for everything else, including consumer-facing markdown
(README, SKILL.md, `references/`, `templates/`, CHANGELOG, in-repo runbooks).

## PR body

Every PR (feature, fix, docs, release) uses `.github/pull_request_template.md` verbatim. Six sections, no inventions:
`## Summary`, `## Changelog`, `## Type of Change`, `## Related Issues/Stories`, `## Files Modified`, `## Testing`.

- **No explainer prose anywhere in the body.** User-facing substance only.
- **Summary describes the net diff only**: what merged `main` looks like vs the base branch. Not commit history,
  intermediate state, or overlay mechanics.
- **Zero verification artifacts in the body.** No diff stats, leak-check output, patch-id cherry-check counts, pre-push
  gate results, CI status, or prose-scrub findings. Anomalies get fixed before push, not audit-trailed.
- **Changelog** subsections (`### Added` / `### Changed` / `### Fixed` / `### Documentation`): 1-5 bullets each, delete
  empty subsections, each bullet starts with a verb. `scripts/generate-changelog.py` extracts these bullets verbatim
  into `CHANGELOG.md`; a PR that lands with an empty `## Changelog` contributes only its title.
- **Type of Change**: one checkbox. Prefer `feat`/`fix` over `chore` for any user-observable change.
- **Related Issues/Stories**: four labels (`Story:` / `Issue:` / `Architecture:` / `Related PRs:`). All four required
  even when empty (`- None.` / `n/a`).
- **Files Modified**: four sub-headers (`Modified` / `Created` / `Renamed` / `Deleted`). All four required even when
  empty.
- **No AI attribution** in commits or PR bodies.
- **No hard line wraps**: one logical line per paragraph or bullet.

→ Rationale: [`RELEASES-RATIONALE.md` § PR body conventions](./RELEASES-RATIONALE.md#pr-body-conventions).

## Releasing dev to main

Before cutting a release branch, walk [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md) end-to-end. Any unchecked item
holds the release.

Engineering docs (`docs/plans/`, `docs/solutions/`, `docs/brainstorms/`, `docs/reviews/`) live on `dev` only.
`guard-main-docs.yml` blocks them from reaching `main`, and `guard-release-branch.yml` rejects any PR to main whose head
isn't `release/*`.

**Branch naming**: `release/v<version>` or `release/v<version>-<slug>`. `generate-changelog.py` extracts the version
from the branch name, so the `v<version>` prefix is required.

`main` and `dev` share only an ancient merge-base: every release squash-merges into `main`, so the two branches diverge
in history even as their content converges. Reconciling that with a merge, or a branch cut from `dev`, produces a pile
of rename/delete conflicts that are artifacts of the lineage, not of the content shipping. The release branch is
therefore built as a **clean descendant of `main`** with `dev`'s tree overlaid on top, asserting the desired end-state
directly:

```bash
# 0. Nothing on main that dev never received (security PRs, hotfixes, config). Exits 1 while drift exists.
scripts/release/drift.sh

# 1. Branch from main, NOT dev.
git fetch origin
git checkout -B release/v<version> origin/main

# 2. Overlay dev's entire tracked tree onto the main base. `checkout -- .` writes dev's
#    paths but does not delete files that exist on main and are absent on dev, so remove
#    those next (the 'D' rows are main-only files dev deleted).
git checkout origin/dev -- .
git diff --name-status origin/main origin/dev | grep '^D'
trash <each main-only file listed above>

# 3. Strip the paths guard-main-docs forbids on main. The set resolves from the workflow;
#    never restate it inline, because every hand-kept copy drifted from what CI enforces.
GUARDED="$(scripts/release/guarded-paths.sh)"
git ls-files | grep -E "$GUARDED" | xargs -r trash
git add -A                                                      # stages adds, mods, AND deletions

# 4. Version bump (plain-text VERSION, no leading "v"), then the changelog from the PRs
#    merged into dev since the previous release. The overlay commit carries no per-PR
#    history, so the section is built from dev's PRs, not from this branch's commits.
printf '%s\n' '<version>' > VERSION
scripts/generate-changelog.py --from-dev-prs
git add -A

# 5. Verify before committing.
#    A: staged tree equals dev's minus the version files and the stripped guarded paths.
#       Anything else printed here is a mistake.
git diff --cached --name-only origin/dev | grep -Ev "$GUARDED" \
  | grep -Ev '^(VERSION|CHANGELOG\.md)$' \
  && echo "unexpected delta above; investigate" || echo "(clean: only intended deltas)"
#    B: no guarded path in the release tree.
git diff --cached --name-only origin/main | grep -E "$GUARDED" \
  && echo "LEAKED a guarded path: reset and redo" || echo "(no guarded paths)"
#    D: what this release ADDS to main. The leak check screens against the registered
#       set, so it is blind to a category nobody registered yet. Every docs/ entry and
#       every added markdown file needs a reason to ship, or it needs registering in the
#       workflow's extra_paths and removing from the branch.
git diff --cached --diff-filter=A --name-only origin/main | grep -E '(^docs/|\.md$)' | grep -Ev "$GUARDED" || echo "(none unguarded)"

# 6. Commit the overlay as one commit sitting directly on top of main, then re-run the
#    drift gate against it and walk the manual gates in RELEASES-PREFLIGHT.md.
git commit
scripts/release/drift.sh

# 7. Push and open the PR. Scrub body in /tmp/ first.
git push -u origin release/v<version>
gh pr create --base main --head release/v<version> --title "release: v<version>" --body-file /tmp/body.md
```

The result is a single commit whose diff against `main` is the release, with `main` as an ancestor, so the PR merges
with zero conflicts. Auto-delete removes `release/v<version>` from the remote on merge. `dev` is untouched.

→ Rationale (why overlay, not merge; why cut from `main`):
[`RELEASES-RATIONALE.md` § Branching model](./RELEASES-RATIONALE.md#branching-model). CHANGELOG mechanics:
[`RELEASES-RATIONALE.md` § CHANGELOG generation](./RELEASES-RATIONALE.md#changelog-generation).

### Exception: cherry-pick

The overlay is the release construction for this repo. Cherry-picking the dev squash-commits onto the `origin/main`
base is an exception for a repo with a stated reason it cannot overlay; `bird-skill` has none, so this section is the
fallback recipe, not the default. When cherry-picking, run the triple-diff verification:

```bash
# 2. List the dev commits not yet on main.
git log --oneline dev --not origin/main

# 3. Cherry-pick the ones to ship. Docs commits stay on dev.
git cherry-pick <sha1> <sha2> ...

# 4. Triple-diff verification.
GUARDED="$(scripts/release/guarded-paths.sh)"

git diff origin/main..HEAD --stat                                              # A: ship surface
git diff HEAD..origin/dev --name-only | grep -Ev "$GUARDED" || echo "(none)"   # B: no missed picks
git diff origin/dev..origin/main --stat | tail -5                              # C: phantom-commits sanity

# Re-confirm no guarded paths leaked.
git diff origin/main..HEAD --name-only \
  | grep -E "$GUARDED" \
  && echo "LEAKED: reset and redo" || echo "(clean)"

# D: what this release ADDS to main (see step 5 above for why).
git diff origin/main..HEAD --diff-filter=A --name-only | grep -E '(^docs/|\.md$)' | grep -Ev "$GUARDED" || echo "(none unguarded)"

# Patch-id cherry check (noisy in squash-merge workflow; triage per-line).
git cherry HEAD origin/dev | grep '^+' || echo "(none)"
```

Cherry-picks of PRs that touched guarded paths hit modify/delete or rename/delete conflicts, since those paths live on
`dev` but are blocked from `main`; resolve them per the next section. Steps 4 to 7 of the overlay recipe then apply
unchanged.

→ Triple-diff false-positive triage:
[`RELEASES-RATIONALE.md` § Triple-diff verification](./RELEASES-RATIONALE.md#triple-diff-verification).

### Cherry-pick conflicts on guarded paths

Cherry-picks of feature PRs that touched a guarded path will hit modify/delete conflicts on the release branch. Those
paths exist on `dev` but are blocked from `main` by `guard-main-docs.yml`, so the cherry-pick sees them as "deleted in
HEAD, modified in `<commit>`". A PR that renames such a file also produces rename/delete conflicts on the same paths.

Resolution (the standard `git rm` is denied by repo policy; use the plumbing form):

```bash
# 1. Mark every unmerged guarded path as deleted in the index.
git update-index --remove $(git diff --name-only --diff-filter=U)

# 2. Trash the orphan worktree files left by the rename target side.
trash docs/plans/<leftover-paths>.md

# 3. Continue the cherry-pick.
git cherry-pick --continue --no-edit
```

Repeat per conflicting commit. After all picks land, run `git ls-files | grep -E "$(scripts/release/guarded-paths.sh)"`.
If anything remains, drop it with the same two-step pattern and commit as `chore(release): drop stray plan spikes from
cherry-pick rename detection` before the leak check.

## Tagging and publishing

After the `release/v<version> → main` PR merges, tag, push, and publish the GitHub Release. There is no tag-triggered
workflow in this repo; the release is the tag plus the GitHub Release, and consumers pick it up on their next
`bird skill update <host>` (a fresh depth-1 clone of `main`).

```bash
git checkout main && git pull
git tag -a -m "Release v<version>" v<version>
git push origin main --tags
gh release create v<version> --title "v<version>" --notes-file /tmp/release-notes.md
```

Always use annotated tags (`-a -m`). The release notes are the new `CHANGELOG.md` section, saved to `/tmp/` and scrubbed
per [§ Prose scrubbing](#prose-scrubbing). `scripts/sync-dev-after-release.sh` refuses to run until the GitHub Release
exists and is not a draft, so the release step is not optional.

→ Rationale (annotated-tag gotcha):
[`RELEASES-RATIONALE.md` § Release pipeline](./RELEASES-RATIONALE.md#release-pipeline).

### After publish: sync `dev` with the release

Once the GitHub Release is published, bring the release bookkeeping (`VERSION`, `CHANGELOG.md`) back to `dev` so the
integration branch starts from the released baseline:

```bash
scripts/sync-dev-after-release.sh v<version>
```

The script opens a PR against `dev`; merge it once CI is green. Never merge `main` into `dev` or push to `dev` directly:
the squash-merged histories share no recent ancestry, so the merge conflicts on every file both sides touched, and a
direct push bypasses `dev`'s required checks.

The backport is idempotent: re-running on a `dev` already in sync exits 0 without creating a branch or PR.

→ Rationale: [`RELEASES-RATIONALE.md` § Release pipeline](./RELEASES-RATIONALE.md#release-pipeline).

## Rollback

A bad release is rolled back at the surface users consume first, then repaired in git. For `bird-skill` that surface is
`main` itself: `bird skill install` and `bird skill update` clone the default branch at depth 1, so whatever `main`
holds is what every consumer receives on their next update. There is no deployment id to re-point or registry version to
yank; the rollback is a revert release. Knowing the last-good tag before the release goes out is a
[`RELEASES-POSTFLIGHT.md`](./RELEASES-POSTFLIGHT.md) gate.

```bash
# 1. Cut a release branch from main and revert the bad release's squash commit.
git fetch origin
git checkout -B release/v<next-patch> origin/main
git revert --no-edit <bad-release-squash-sha>

# 2. Bump VERSION, regenerate the changelog, and ship through the normal PR to main.
printf '%s\n' '<next-patch>' > VERSION
scripts/generate-changelog.py --tag v<next-patch>
git add -A && git commit
git push -u origin release/v<next-patch>
gh pr create --base main --head release/v<next-patch> --title "release: v<next-patch>" --body-file /tmp/body.md

# 3. Tag and publish per § Tagging and publishing, then mark the bad GitHub Release as a pre-release so
#    `gh release view` and the releases page stop advertising it as latest.
gh release edit v<bad-version> --prerelease
```

Consumers who already updated onto the bad release recover with `bird skill update <host>` once the revert release is on
`main`. The `fix/*` that addresses the underlying defect lands through `dev` afterwards like any other change.

→ Rationale: [`RELEASES-RATIONALE.md` § Rollback](./RELEASES-RATIONALE.md#rollback).

## Prose scrubbing

Three release-flow artifacts live outside any automated prose check and need a manual scrub before they ship:

- PR bodies (`gh pr create` / `gh pr edit` send body text directly to GitHub).
- `CHANGELOG.md` (a generated artifact built from upstream PR bodies).
- Release-PR bodies and GitHub Release notes (composed after `CHANGELOG.md` has been generated).

```bash
# 1. Save the artifact to /tmp/.
gh pr view <num> --json body --jq .body > /tmp/body.md         # for PR body edits
# cp CHANGELOG.md /tmp/body.md                                 # for changelog scrub

# 2. unslop (em-dash density and AI-unique structural patterns).
~/.claude/skills/unslop/scripts/score.py /tmp/body.md

# 3. Apply fixes per finding. Re-run until the score is 0.

# 4. Apply the cleaned version.
gh pr edit <num> --body-file /tmp/body.md     # for PR body edits
```

For a `CHANGELOG.md` finding, fix the upstream PR body (which `generate-changelog.py` re-fetches every run) and
regenerate. Hand-editing `CHANGELOG.md` directly produces drift the next regeneration overwrites.

→ Rationale + which artifacts need this:
[`RELEASES-RATIONALE.md` § Prose scrubbing scope](./RELEASES-RATIONALE.md#prose-scrubbing-scope).

## Branch protection

Two rulesets are committed under `.github/rulesets/` and applied to the repo via the GitHub API:

- `ruleset-protect-main.json` (required signatures, linear history, squash-only merges via PR, required status checks
  `guard-docs / check-forbidden-docs`, `guard-release / check-release-branch-name`, `guard-provenance /
  check-provenance`, `markdownlint`; creation/deletion blocked, non-fast-forward blocked).
- `ruleset-protect-dev.json` (required signatures, deletion blocked, non-fast-forward blocked). PR-only norm is
  convention + `guard-release-branch` on the main side.

### Applying changes

```bash
# First apply (creating a ruleset):
gh api -X POST repos/brettdavies/bird-skill/rulesets --input .github/rulesets/ruleset-protect-dev.json

# Subsequent updates (replace by ID; find via `gh api repos/brettdavies/bird-skill/rulesets`):
gh api -X PUT repos/brettdavies/bird-skill/rulesets/<id> --input .github/rulesets/ruleset-protect-main.json
```

→ Status-check context strings (inline vs reusable):
[`RELEASES-RATIONALE.md` § Status-check context strings](./RELEASES-RATIONALE.md#status-check-context-strings).

## Project specifics

`bird-skill` is a docs-only skill bundle: markdown plus the consumer-side `scripts/write-op-gate.sh`. Nothing compiles
and nothing deploys.

| Item                 | Value                                                                                                 |
| -------------------- | ----------------------------------------------------------------------------------------------------- |
| Version carrier      | `VERSION` (plain text, no leading `v`). `sync-dev-after-release.sh` creates it on the first backport. |
| Distribution channel | `bird skill install <host>` / `bird skill update <host>`: a hardened `git clone --depth 1` of `main`. |
| Release artifact     | Annotated `v<version>` tag plus a GitHub Release whose notes are the matching `CHANGELOG.md` section. |
| Release workflow     | None. Tag and Release are pushed by hand per [§ Tagging and publishing](#tagging-and-publishing).     |
| Required secrets     | None. `gh` auth on the maintainer's machine is the only credential.                                   |
| Rollback surface     | `main`. See [§ Rollback](#rollback).                                                                  |
| Preflight script     | None vendored; [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md) is walked by hand after `drift.sh`. |

## Related docs

- [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md): pre-cut go/no-go checklist gating release-branch creation.
- [`RELEASES-POSTFLIGHT.md`](./RELEASES-POSTFLIGHT.md): post-tag verification and backport.
- [`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md), release-flow rationale: branching, PR body, pipeline, prose-check.
- [`.github/pull_request_template.md`](.github/pull_request_template.md): PR body structure with changelog sections.
- [`README.md`](README.md): install path and bundle layout.

# Post-release verification: `bird-skill`

Operational post-flight checklist. Runs **after** the `release/v<version> → main` PR merges and you push the tag and
create the GitHub Release per [`RELEASES.md` § Tagging and publishing](./RELEASES.md#tagging-and-publishing). Verifies
that the published release is what consumers receive on their next `bird skill update`, and that the release
bookkeeping made it back to `dev`.

Companion to [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md), which gates the release-branch cut. Both docs follow
the same go/no-go shape: every box is explicit, an unchecked or red item holds the next release (or motivates a
rollback).

## Quick start

`bird-skill` vendors no `postflight.sh`: there is no `release.yml`, no homebrew-tap dispatch, no registry publish, and
no deployed surface for a script to poll. The checklist below is walked by hand. The one scripted step is the backport:

```bash
scripts/sync-dev-after-release.sh v<version>
```

## Checklist

Run immediately after the tag push and `gh release create`.

- [ ] **Tag is annotated and on `main`.** `git tag -l --format='%(objecttype) %(refname:short)' v<version>` prints
  `tag v<version>` (not `commit`), and `git merge-base --is-ancestor v<version> origin/main` exits 0.
- [ ] **GitHub Release is published, not draft.** `gh release view v<version> --json isDraft,isPrerelease,tagName`
  reports `isDraft: false`, `isPrerelease: false`, and the tag. `gh api repos/brettdavies/bird-skill/releases/latest
  --jq .tag_name` returns `v<version>`, not the previous tag.
- [ ] **Release notes match `CHANGELOG.md`.** The Release body is the `## [<version>]` section of `CHANGELOG.md` on
  `main`, scrubbed per [`RELEASES.md` § Prose scrubbing](./RELEASES.md#prose-scrubbing). A mismatch means the notes
  were hand-edited after generation; fix the upstream PR body and regenerate.
- [ ] **Live consumer sanity probe.** `bird skill update <host>` on a machine with the previous release installed, then
  `head -3 ~/.claude/skills/bird/SKILL.md` (or the host-equivalent path) shows the new content and
  `cat ~/.claude/skills/bird/VERSION` prints `<version>`. Confirms the depth-1 clone of `main` serves the release.
- [ ] **Bundle install probe on a clean host.** `bird skill install <host>` into a destination that did not exist,
  against a different host slug than the update probe. Confirms the install path and the update path both resolve the
  same tree.
- [ ] **Last-good identifier recorded.** Before this release went live, note the previous tag (`git tag
  --sort=-version:refname | sed -n 2p`) and the squash SHA of this release on `main` (`git log -1 --format=%h
  origin/main`) somewhere reachable under incident pressure. A rollback is a `git revert` of that SHA; see
  [`RELEASES.md` § Rollback](./RELEASES.md#rollback).
- [ ] **Rollback path confirmed.** If this release is bad, cut `release/v<next-patch>` from `main`, revert the release
  squash commit, and ship it through the normal PR to `main` so consumers' next `bird skill update` receives the
  last-good tree. Mark the bad GitHub Release as a pre-release afterwards.
- [ ] **Backport `main` → `dev`** via a **merged PR to `dev` with the version in its title.** Run
  `scripts/sync-dev-after-release.sh v<version>`; it writes `VERSION` (creating it on the first release that uses
  this flow), copies `CHANGELOG.md` from `main`, and opens `chore/sync-dev-after-v<version>` against `dev`. Merge it
  once CI is green. Keeps the next release's diff-A quiet so a real missed path stands out instead of hiding in
  expected divergence noise.

  The script is idempotent: re-running on a `dev` already in sync exits 0 without creating a branch or PR. Never merge
  `main` into `dev` and never push to `dev` directly.

- [ ] **`drift.sh` is quiet after the backport.** `scripts/release/drift.sh` exits 0 once the sync PR merges. Anything
  it still lists is a change that reached `main` outside the release flow and needs its own backport PR.

## Related docs

- [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md): pre-cut go/no-go checklist (runs BEFORE this one).
- [`RELEASES.md`](./RELEASES.md): operational runbook for the full release lifecycle.
- [`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md): release-flow rationale.

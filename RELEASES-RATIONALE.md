# Releases rationale

Companion to [`RELEASES.md`](./RELEASES.md). RELEASES.md is the runbook (commands, paths, decision tables). This file
holds the WHY behind those rules: branching model, PR conventions, release pipeline, CHANGELOG generation, rollback,
prose-check scope, branch-protection pitfalls.

Read this when:

- A rule in RELEASES.md doesn't make sense and you're tempted to change it.
- A new contributor asks "why do we do X this way".
- You're adding a new release-flow rule and need to know where it fits the existing model.

## Branching model

### Forever `dev`, ephemeral release branches

`dev` is never deleted, even after a release. The next release cycle reuses the same `dev`. The repo's
`deleteBranchOnMerge: true` setting doesn't touch `dev` as long as `dev` is never the head of a PR. Using a short-lived
`release/*` head is what keeps the setting compatible with a forever integration branch.

Engineering docs (`docs/plans/`, `docs/solutions/`, `docs/brainstorms/`, `docs/reviews/`) live on `dev` only. They never
reach `main`. `guard-main-docs.yml` blocks them from PRs targeting `main`, and `guard-release-branch.yml` rejects any PR
to main whose head isn't `release/*`.

### Why the release branch is cut from `main`, never from `dev`

Every release squash-merges into `main`, so `dev` and `main` diverge in history even as their content converges: after
the first release they share only an ancient merge-base. Cutting the release branch from `dev` (or merging `dev` into
`main`) forces a 3-way merge across that divergence: `add/add` collisions on files both sides changed, plus
rename/delete pairs git cannot auto-resolve. The conflict pile is an artifact of the lineage, not of the content
shipping.

Always cut the release branch from `origin/main` and bring `dev`'s content onto it as a forward diff, never by
reconciling histories. The default is the whole-tree overlay (`git checkout origin/dev -- .`, then strip the guarded
set): `main` ships `dev`'s tree minus a small, known exclusion set, so asserting that end-state directly is simpler and
safer than hand-resolving a merge. The overlay commit carries no per-PR history, so the changelog is built from the
PRs merged into `dev` since the previous release (`generate-changelog.py --from-dev-prs`) rather than from the
branch's commits; the result is the same per-PR section a cherry-picked branch would yield. Cherry-picking the dev
squash-commits is kept only as an exception for a repo with a stated reason it cannot overlay, at the cost of
guarded-path conflict handling.

Either way, the release must start from a `main` that `dev` fully contains. Security PRs, hotfixes, and config edits
land on `main` first, and both constructions take `dev`'s content for the files they touch, so anything `main` holds
that `dev` never received is reverted by the release. `scripts/release/drift.sh` lists that set and the cut waits
until it is empty.

### Why `main` is the default branch + release pointer

Consumers install via `bird skill install <host>`, a hardened `git clone --depth 1` of the default branch, or by tag
(`git checkout v<X.Y.Z>` after fetch). `main` is therefore the published-release pointer; `dev` is the integration
branch. Each release requires the maintainer to advance `main` to the new tag, which the `release/* → main` PR
squash-merge does. Any update-check tooling that compares a local copy against the producer repo also reads `main`, so
`main` must always reflect the latest released state.

### Version branch naming

Branch naming `release/v<version>` or `release/v<version>-<slug>` makes release branches sortable and unambiguous when
multiple cuts are in flight. `generate-changelog.py` extracts the version from the branch name, so the `v<version>`
prefix is required. Slug is kebab-case, short, descriptive.

## PR body conventions

### No explainer prose in the body

Every section of a PR body is user-facing substance only: the **net diff**, what is changing for the consumer that was
not already there, not the commit history or intermediate state that produced it. Workflow mechanics (overlay,
regenerate, pre-push gate, CI behavior) are documented in RELEASES.md and `.github/`, NOT in the PR body. Diff output,
leak-check narration, patch-id cherry-check counts, pre-push gate results, CI check status, exclusion rationale, and
other verification artifacts stay local; anomalies get fixed before push, not audit-trailed in the body.

The PR body is read by humans reviewing what shipped. Workflow mechanics and tool-fix provenance are noise from that
perspective; they belong in this file, the script outputs, and the commit history respectively.

### Why `feat`/`fix` are preferred over `chore`

`cliff.toml` drops commits whose subject starts with `chore`, `style`, `test`, `ci`, or `build` regardless of body
content. Mistyping a user-facing change as `chore` silently strips it from release notes. Prefer `feat` / `fix` when the
change has any user-observable effect (a new reference doc, a changed script flag, a new `bird` verb the skill teaches).

Security advisory bumps in particular use `fix(deps):`, never `chore(deps):`, so they appear in the changelog. A bumped
dependency that closes a CVE is user-visible value, not internal tooling.

### Why required-when-empty sub-headers

`Related Issues/Stories` has four labels (`Story:` / `Issue:` / `Architecture:` / `Related PRs:`). `Files Modified` has
four sub-headers (`Modified` / `Created` / `Renamed` / `Deleted`). All four must appear in every PR, even when empty:
write `- None.` or `n/a` rather than deleting the label. Reason: scanners and humans both rely on a known section shape.
Conditionally-absent sections force every reader to mentally check "did the author skip this or does it not apply?"

### Why no AI attribution

`Co-Authored-By: Claude ...`, robot emoji / "Generated with Claude Code" trailers, or any similar AI-attribution trailer
is banned from commit messages and PR bodies. Commits and PRs stand on their own technical content. Attribution trailers
are noise and they age poorly as tools shift.

### Why no hard line wraps

Author each paragraph and each bullet as one logical line, however long. GitHub soft-wraps for display. Hard wraps
within prose produce visible mid-sentence breaks in some renderers and interfere with prose-check tooling that reports
findings against split lines.

### Why internal-tooling commits don't appear in `## Changelog`

`chore(cliff): ...`, `chore(ci): ...`, and similar internal-tooling commits don't appear in the PR body's `##
Changelog`. They are not user-facing. They belong in commit history and in the Files Modified section of the PR body,
not in the source-of-truth release notes.

## Triple-diff verification

The cherry-pick exception runs three diffs (A: main→release, B: release→dev filtered by the guarded set, C: dev→main)
plus a patch-id cherry check. This is belt-and-suspenders because missed cherry-picks have shipped to `main` on sibling
repos before, and the file-level diff in B alone doesn't catch the patch-id false-negative class. The overlay recipe
keeps diff A (staged tree vs `dev`), the leak check, and step D; B and C are moot when the whole tree is taken.

### Why the guarded set resolves from the workflow

`guard-main-docs` is what CI enforces on a PR to `main`: the reusable workflow's hardcoded base list plus this repo's
`extra_paths`. Every hand-kept copy of that union (runbook, checklist, preflight script) drifted from it, and a copy
that omits a guarded path reports a real leak as clean while CI turns red after the push.
`scripts/release/guarded-paths.sh` reads `extra_paths` out of the caller workflow and adds the base list, so
registering a path in the workflow is the only edit a new guarded path needs. The base list is the one copy that still
needs a manual edit when the reusable changes, because it lives in another repo. Entries are globs with one rule set
shared by the reusable and the script (`**/` any depth, `*` and `?` within a segment, trailing slash guards the
subtree), so `**/.agent/` guards that directory wherever it appears and the two never disagree about what is guarded.

### Why the release enumerates what it adds

The leak check screens the diff against the registered set, so it says nothing about a category nobody registered. A
new engineering directory or a stray note under `docs/` passes the local check and `guard-main-docs` alike. Step D
lists every `docs/` file and every markdown file the release adds to `main` outside the guarded set and puts them in
front of a human; each one needs a reason to ship, or it gets registered in `extra_paths` and dropped from the branch.
Root-level markdown is in scope because an agent-facing glossary at the repo root is exactly the kind of addition a
`docs/`-only listing misses, and for a skill bundle every root markdown file ships to consumers.

### Why patch-id cherry-check output is noisy

In a squash-merge workflow, `git cherry HEAD origin/dev` produces many `+` lines that need human triage. They do NOT
auto-block the release. Expected sources of false positives:

1. **Historical commits squash-merged in prior releases.** The squash commit on main has a different patch-id than the
   dev commits it consolidates, so old commits show as `+` forever. Anything older than the previous release tag is
   almost always this.
2. **Cherry-picks where conflict resolution stripped guarded paths** (`docs/plans/`, `docs/brainstorms/`, etc.) or
   otherwise altered the tree. Same source-code intent, different patch-id.
3. **Intentionally skipped commits** (docs-only commits, release-prep backports, revert-and-redo prep steps).

A real miss looks like: a recent feat/fix/chore commit on dev whose *file content* is not yet on main. To triage a `+`
line:

```bash
git show <sha> --stat                       # what did it touch?
git diff origin/main..HEAD -- <those-files> # already on release?
```

If every touched file is guarded OR the content is already on main via a prior squash, it's a false positive (no
action). Otherwise cherry-pick the commit and re-run the triple-diff.

## CHANGELOG generation

### Generated, never hand-written

`scripts/generate-changelog.py` (vendored from the `github-repo-setup` skill, with the repo-local `cliff.toml`) is the
only sanctioned way to update `CHANGELOG.md`. On an overlay-built release branch it runs as `--from-dev-prs`: the PRs
merged into `dev` since the previous release are the entries, and each PR's body supplies its `## Changelog → ###
Breaking changes / Added / Changed / Fixed / Documentation` subsections (with author and PR-link attribution). On a
cherry-picked branch it runs `git-cliff` first to prepend a versioned entry from the branch's commits, then expands
the same way.

If a PR's body carries no changelog content, its title becomes a `Changed` bullet, except for `chore`, `ci`, `build`,
`style`, and `test` PRs, which stay out unless they carry a `## Changelog` of their own. To fix a wrong CHANGELOG entry,
fix the input: edit the squash-merged PR body, then re-run the script. Do **not** edit `CHANGELOG.md` directly.

`scripts/generate-changelog.py --check` verifies that `CHANGELOG.md` has a versioned section (not just `[Unreleased]`).
This repo has no release-branch CI job; the check is a [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md) row.

### Why `cliff.toml` skips chore/style/test/ci/build

These commit types do not produce user-facing content. If a PR has user-facing `## Changelog` content but its commit
subject starts with one of those types, its bullets get silently dropped. After running the script, cross-check the
generated section against `gh pr view <num> --json body` for each PR in the window; correct mistyped PR titles (e.g.
`chore` → `feat`) and re-run. See "Prefer `feat`/`fix` over `chore`" above for prevention.

## Release pipeline

### Annotated tags and a hand-pushed Release

Always use annotated tags (`-a -m`). Bare `git tag <name>` silently fails with `fatal: no tag message?` on machines
where `tag.gpgsign=true` is set globally.

`bird-skill` has no tag-triggered workflow. The bundle is markdown plus one shell script, so there is nothing to
compile, publish to a registry, or bottle. The release is the annotated tag plus a GitHub Release created with `gh
release create`, whose notes are the matching `CHANGELOG.md` section. The GitHub Release is not decorative:
`scripts/sync-dev-after-release.sh` refuses to backport until it exists and is not a draft, because a tag without a
Release is invisible to `gh release view` and to anyone browsing the releases page.

### Why backport `main` → `dev` after publish

Once the GitHub Release is published, the release-bookkeeping files on `main` (`VERSION`, `CHANGELOG.md`) need to reach
`dev` so future feature branches inherit the released baseline. Without the backport, `dev` keeps the pre-release
`VERSION` indefinitely: the release bump lives only on the `release/*` branch that was squash-merged to `main` and never
touched `dev`.

The backport is a PR opened by `scripts/sync-dev-after-release.sh`, never a merge of `main` into `dev` and never a
direct push. The squash-merged branches share no recent history, so a merge conflicts on every file both sides
touched, and a direct push to `dev` bypasses its required status checks. The script writes the released version into
every version carrier present (for this repo, `VERSION`, which it creates on the first run), copies `CHANGELOG.md` from
`main` when `main` carries one, and opens the PR. The diff is mechanical, so reviewers can spot-check and squash-merge as
usual.

The script is idempotent: it exits 0 without creating a branch or PR when the synced files already match `main`. Safe
to re-run, safe to invoke from automation that doesn't track whether the last release was already backported.

### Rollback

Rollback happens at the surface users consume, not by rewriting history. For most repos that surface is a deployment,
a registry, or a formula, and re-pointing it is fast and reversible while rewriting `main` is neither. For
`bird-skill` the surface **is** `main`: every `bird skill update` is a fresh depth-1 clone of the default branch, so
the only way to change what consumers receive is to move `main` forward. A rollback is therefore a revert release:
`git revert` of the bad squash commit on a `release/*` branch, through the normal PR to `main`, then a new tag. The
release flow exists so that `main` only ever moves forward through a PR, and the rollback respects that. Recording the
last-good tag before the release goes out is what makes the revert a single command under incident pressure.

Marking the bad GitHub Release as a pre-release afterwards keeps `gh release view` and the releases page from
advertising it as latest; it does not change what consumers clone.

## Prose scrubbing scope

Three release-flow artifacts live outside any automated prose check and need a manual scrub before they ship:

- **PR bodies.** `gh pr create` and `gh pr edit` send body text directly to GitHub; no automated prose check has reach
  there.
- **`CHANGELOG.md`.** A generated artifact built from upstream PR bodies; it inherits whatever prose those PR bodies
  carry, so scrubbing happens at generation time on the release branch.
- **Release-PR bodies and GitHub Release notes.** The `release/v<version>` PR to `main` and the `gh release create`
  notes carry contributor-authored wrap-up text composed after `CHANGELOG.md` has been generated, and the same
  out-of-repo gap applies.

Scrub-before-submit (author in `/tmp/`, scrub there, submit via `--body-file` / `--notes-file`) avoids the round-trip of
"submit, scrub, edit, scrub again". Every fix lands locally and the public PR sees only clean text. The auto-format hook
skips `/tmp/` paths so the body keeps its authored shape and no soft-wrapping is injected.

For a `CHANGELOG.md` finding, fix the upstream PR body (which `generate-changelog.py` re-fetches every run) and
regenerate. Hand-editing `CHANGELOG.md` directly produces drift the next regeneration overwrites.

## Branch protection

### Why two rulesets

`ruleset-protect-main.json` and `ruleset-protect-dev.json` ship in `.github/rulesets/` and are applied via the GitHub
API. The apply commands in RELEASES.md are deliberately idempotent so they survive a ruleset reset and the same
procedure being copied into a new repo's bootstrap. A tag-protection ruleset (`v*` tags immutable) is the natural third
member once the first tag exists; consumers who fetch by tag rely on tag identity, and a re-tagged release would lie
about what they're installing.

### Status-check context strings

The `required_status_checks[].context` strings in `ruleset-protect-main.json` MUST match exactly what GitHub publishes
for each check:

- **Inline job** (with `name:` field): published as just `<job-name>` (no workflow-name prefix).
- **Reusable-workflow caller** (`uses: .../foo.yml@ref`): published as `<caller-job-id> / <reusable-job-id-or-name>`.

Mixing these produces a stuck-but-green PR: all actual checks report green, but the ruleset waits forever on a context
that will never appear. Confirm the real contexts after a first CI run with:

```bash
gh api repos/<owner>/<repo>/commits/<sha>/check-runs --jq '.check_runs[].name'
```

### Why rulesets live in-repo

Committing the JSON alongside code means ruleset changes land via the same review process as workflow changes. A
`chore(ci): tighten protect-main` change goes through dev → release/* → main like anything else.

## Related docs

- [`RELEASES.md`](./RELEASES.md): operational runbook (commands, paths, decision tables).
- [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md): pre-cut checklist gating the release-branch cut.
- [`RELEASES-POSTFLIGHT.md`](./RELEASES-POSTFLIGHT.md): post-tag verification and backport.
- [`.github/pull_request_template.md`](.github/pull_request_template.md): PR body structure with changelog sections.

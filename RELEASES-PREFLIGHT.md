# Pre-release verification

Operational pre-flight checklist. Runs **before** step 1 of
[`RELEASES.md` § Releasing dev to main](./RELEASES.md#releasing-dev-to-main). Gates the cut of the `release/v<version>`
branch, not the daily dev integration. Each box is an explicit go/no-go. If any item is unchecked or red, hold the
release.

CI catches mechanical regressions inside this repo (lint, test, format, signatures). This checklist covers what CI
structurally can't:

- Breaking changes to a contract that downstream consumers must adapt to (JSON shape, CLI surface, bundle layout).
- Real-world behavior against external systems CI only mocks.
- Distribution paths that only exercise on real artifacts (cross-compile binaries, `git clone` to a real install
  destination, package-manager install from a clean machine).
- Cross-repo sequencing where releasing here before a sibling repo is ready breaks downstreams.

> **Repo-type applicability.** Items marked **[Rust CLI]** apply to repos that ship a Rust binary (cargo + crates.io +
> homebrew tap). Skill-bundle and tooling repos can mark those rows `N/A` with a one-line reason. Items not marked are
> universal (apply to all release-flow repos).

## Establish the surface

Everything below assumes you know what's changing. Run this first.

```bash
LAST_TAG=$(git tag --sort=-version:refname | head -n 1)
git log "$LAST_TAG..dev" --oneline                              # commits going out
git diff "$LAST_TAG..dev" --stat                                # file-level scope
git log "$LAST_TAG..dev" --grep '^[a-z]\+!:' --oneline          # Conventional-Commits breaking markers
```

Every `!:` commit drives the major-version decision and gets a row in the release's `### Breaking changes` section.

## Checklist

### Cross-repo blast radius

- [ ] **Contract diff.** Diff every consumer-facing contract (JSON shape, CLI surface, bundle layout, public API)
  between `$LAST_TAG` and `dev`. Every field renamed / added / removed / shape-changed becomes a row in the release's
  `### Breaking changes` (consumers feature-detect from this list).
- [ ] **Downstream consumers ready.** Sibling repos that read this release's output (e.g. a site renders the new JSON
  shape correctly, no `undefined` fields, the new `schema_version` is recognized). If a downstream is not ready, hold
  the tag.
- [ ] **Version-cross references.** If this repo vendors content from a sibling, the vendored copy's `VERSION` matches
  the source's tag, and any field that references the vendored version is also bumped.
- [ ] **Install-path destinations.** Every install URL or path the release will resolve to (skill-install destinations,
  homebrew tap, package-manager URLs) actually exists. The destination branch the install command targets exists.

### Real-world smoke

CI exercises one shape; manual probes cover the rest. Pick fresh targets each release.

- [ ] **Skill bundle: install + load.** `<binary> skill install <host>` for each host slug, against a clean per-host
  destination directory. Confirms the hardened `git clone` reaches the live bundle repo, not just a test fixture.
- [ ] **Rust CLI: cross-target audit.** **[Rust CLI]** Run the tool against fresh real-world targets representing each
  ecosystem you care about (e.g. one Python repo, one Go repo, one POSIX-style tool). Confirms the audit produces
  non-empty output without panic across the expected diversity.
- [ ] **Regression markers.** Any bug fixed in this release: re-run against a target that previously demonstrated the
  bug. Confirms the fix lands in the release artifact, not just on `dev`.

### Distribution and install paths

The release builds artifacts and may dispatch downstream. None of this runs in unit tests.

- [ ] **[Rust CLI] Cross-compile** of all targets listed in `RELEASES.md` § Tagging and publishing. If the workflow has
  changed since the last green run, dry-run with `cargo build --release --target <target>` for each.
- [ ] **[Rust CLI] Clean-machine install probe.** In a clean container or fresh machine: download a prior release
  archive, run the binary's `--version` and a non-trivial command. Confirms the archive layout (binary + completions +
  README + licenses) still works without the project's toolchain.
- [ ] **Bundle install probe** (skill bundles). `git clone --depth 1` from the install URL to a fresh directory.
  Confirms the install lands the expected files at the expected paths.

### Release mechanics sanity

These items duplicate steps in `RELEASES.md` deliberately: easy to skip, expensive to recover from. Confirm explicitly.

- [ ] **`VERSION` file bumped** to the new tag value (`v<X.Y.Z>` minus the leading `v` for plain-text VERSION files,
  full `v<X.Y.Z>` for tag-shaped strings).
- [ ] **[Rust CLI] `Cargo.toml` `version` bumped** to the new tag value (CI's `check-version` enforces this; catch
  early).
- [ ] **[Rust CLI] `Cargo.lock` regenerated** via `cargo update -p <crate-name>`, committed.
- [ ] **Rebuild locally** and confirm `<tool> --version` prints the new tag value.
- [ ] **Every merged PR since `$LAST_TAG` has a non-empty `## Changelog` section.** Spot-check via:

  ```bash
  gh pr list --base dev --state merged \
    --search "merged:>$(git log -1 --format=%aI $LAST_TAG)"
  # Then for each PR:
  gh pr view <num> --json body
  ```

- [ ] **[Rust CLI] Toolchain quarantine.** `rust-toolchain.toml` last bumped ≥7 days ago (supply-chain quarantine). If a
  bump landed inside the window, hold or revert it before tagging.
- [ ] **[Rust CLI] No unmerged advisories** from `cargo deny check advisories`.
- [ ] **Leak check.** Engineering-doc paths and `.context/` aren't reaching the release branch:

  ```bash
  git diff origin/main..HEAD --name-only \
    | grep -E '^(docs/plans|docs/brainstorms|docs/ideation|docs/reviews|docs/solutions|\.context)'
  ```

  Returns nothing. If cherry-picks pulled in guarded paths via rename detection, resolve per `RELEASES.md` §
  Cherry-pick conflicts on guarded paths.

### Post-tag verification

Run immediately after the tag push triggers the release workflow.

- [ ] **`release.yml` green end-to-end.** `gh run watch <id> --exit-status` then verify with `gh run view <id> --json
  conclusion`. The watcher exit code alone is not authoritative — re-check explicitly.
- [ ] **[Rust CLI] Homebrew-tap dispatch completed**, then `finalize-release.yml` ran back here and flipped the GitHub
  Release `make_latest: true`.
- [ ] **[Rust CLI] crates.io shows the new version published.** `cargo install <crate> --version <new>` from a clean
  environment resolves and runs.
- [ ] **Live consumer sanity probe.** Click a URL or run a command that fetches the latest release content (badge URL,
  install command, update check). First-time renders for a new version can 404 even when the artifact looks correct.
- [ ] **Run `./scripts/sync-dev-after-release.sh v<version>`** to open the `chore/sync-dev-after-v<version>` PR against
  `dev` per `RELEASES.md` § After publish.

## Related docs

- [`RELEASES.md`](./RELEASES.md): operational runbook this checklist gates.
- [`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md): release-flow rationale.

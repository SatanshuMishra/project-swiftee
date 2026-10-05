# CI and release hardening

Date: 2026-10-04

## Context

From 2026-05-02 to 2026-10-04 every CI run on `main` was red and four PRs (#9 to #12) merged on red, because `main` had no branch protection. Three independent faults sat behind that:

- The CI bundle job could not build once the updater was enabled: `createUpdaterArtifacts: true` with an embedded pubkey makes the Tauri CLI demand `TAURI_SIGNING_PRIVATE_KEY`, which CI builds never receive. A clippy failure masked this until #12.
- Clippy broke with no code change because `dtolnay/rust-toolchain@stable` floated to a release with a new lint.
- The Claude review job never succeeded: no `id-token: write`, no `ANTHROPIC_API_KEY` secret, and the `Skill` tool its `/review-pr` call needs was not allowed.

v0.2.1 shipped from a commit whose CI was red, because the release workflow never consulted CI. Separately, `macos-14` (used by the release macOS build) enters GitHub brownouts on 2026-10-05 and is removed on 2026-11-02 (actions/runner-images#13518).

## Decisions

| Decision | Why |
|---|---|
| CI bundles build with `tauri build --no-sign` instead of tauri-action | Unsigned smoke bundles need no secret, so fork and Dependabot PRs build too; tauri-action added nothing without a release to upload to |
| One aggregate `CI OK` job is the only required check | Matrix renames never orphan the branch rule; the job fails only on a `failure` or `cancelled` dependency |
| Rust pinned in `rust-toolchain.toml`, installed by `actions-rust-lang/setup-rust-toolchain` | New lints arrive as a reviewable Dependabot PR, not a surprise red `main`; that action reads the file, `dtolnay/rust-toolchain` does not |
| Runner images pinned: `ubuntu-24.04`, `macos-26`, `windows-2025` | `ubuntu-latest` moves to 26.04 from 2026-10-19; image moves become deliberate PRs |
| Rust tests run on Linux, macOS and Windows; fmt and clippy on Linux | The app ships only on macOS and Windows; there is no platform-specific Rust code to lint separately |
| Release calls CI through `workflow_call` before creating the draft | No release is built from a commit that fails CI; bundle job skipped there because release builds its own |
| Draft release created once, then both builds upload by `releaseId` | Parallel tauri-action jobs can otherwise create duplicate releases for one tag (tauri-action#914) |
| `verify-manifest` asserts `latest.json` carries the tag version and all four platform keys with url and signature | Parallel jobs read-modify-write `latest.json`; a lost platform entry would silently strand that platform's users |
| No caches in release builds | Release artifacts build from a clean state; costs release wall-clock time |
| Every third-party action pinned to a full commit SHA with a version comment | A moved tag cannot change what runs with the signing key; Dependabot updates SHA pins |
| Per-job permissions in `release.yml`; workflow default `contents: read` | Only jobs that upload or attest get write scopes |
| Every job has `timeout-minutes` | A hung job stops instead of running for the six-hour default |
| `main` pushes get one CI group per commit; PRs cancel superseded runs | Every `main` commit gets a verdict |
| CI runs on every pull request, not only those targeting `main`; fork PRs build but upload no installers | Stacked PRs get CI and installers for VMLab; a fork cannot get an installer hosted under this repository |
| Claude review stays advisory, skips fork and Dependabot PRs, skips with a notice until `ANTHROPIC_API_KEY` exists, and also watches `.github/workflows/**` | Those PRs never receive the API key, and a missing key should not paint every PR red; workflow edits are the riskiest PRs |
| The review agent may read, diff and comment, and is denied edits, npm, cargo, pushes, `git diff --no-index` and merge or review commands; it updates one comment per PR | The action restores `.claude/` and `CLAUDE.md` from the base branch, but package scripts and build scripts still come from the PR head |
| Dependabot never proposes Tauri minor or major bumps; npm and cargo updates wait seven days | The Tauri CLI refuses to build when the crate and npm package minor versions differ, so separate npm and cargo PRs could never merge alone; Tauri minors are bumped by hand in one PR. The cooldown keeps brand-new releases out of a build that later holds signing keys |

## Human steps, in order

1. Merge the CI hardening PR first. The ruleset requires a check named `CI OK`, which only exists once that PR's `ci.yml` is on `main`.
2. Apply the ruleset:
   `gh api -X POST repos/SatanshuMishra/project-swiftee/rulesets --input docs/decisions/2026-10-04-main-ruleset.json`
   Open PRs created before step 1 then need `main` merged in so they report `CI OK`.
3. Enable Dependabot alerts, Dependabot security updates, secret scanning and push protection:
   `gh api -X PUT repos/SatanshuMishra/project-swiftee/vulnerability-alerts`
   `gh api -X PUT repos/SatanshuMishra/project-swiftee/automated-security-fixes`
   `gh api -X PATCH repos/SatanshuMishra/project-swiftee --input - <<< '{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}'`
4. For the Claude review: install the Claude GitHub App on this repository (https://github.com/apps/claude), then `gh secret set ANTHROPIC_API_KEY` and paste the key at the prompt.
5. Locally, the first cargo command after pulling installs Rust 1.99.0 through rustup because of `rust-toolchain.toml`.

## Rollback

- Pipeline: revert the PRs.
- Ruleset: `gh api repos/SatanshuMishra/project-swiftee/rulesets --jq '.[] | select(.name == "main") | .id'`, then `gh api -X DELETE repos/SatanshuMishra/project-swiftee/rulesets/<id>`.
- Security features: `gh api -X DELETE .../vulnerability-alerts`, `gh api -X DELETE .../automated-security-fixes`, and the same PATCH with `"disabled"`.

## Known costs

- A release now runs the full CI first, then builds without caches; expect it to take noticeably longer than the 10 minutes v0.2.1 took.
- `setup-rust-toolchain` sets `CARGO_BUILD_WARNINGS=deny`, so a rustc warning fails any build, release included. With the pinned toolchain, new warnings only arrive through a toolchain bump PR.
- The release flow is unproven until the next tag: nothing in it can run before a `v*` tag is pushed.
- tauri-action v1 (adopted in #12) writes GitHub API asset URLs into `latest.json` instead of browser download URLs. Clients on v0.2.1 run tauri-plugin-updater 2.10.1, whose download sends `Accept: application/octet-stream`, which those URLs require.

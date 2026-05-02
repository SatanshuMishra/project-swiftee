# Auto-Update System — Operator Handoff

**Date:** 2026-05-01
**Branch:** `feat/auto-update-system` (28 commits ahead of `main`)
**Final HEAD:** `1628bda`
**Spec:** [docs/superpowers/specs/2026-04-30-auto-update-system-design.md](../specs/2026-04-30-auto-update-system-design.md)
**Plan:** [docs/superpowers/plans/2026-05-01-auto-update-system.md](../plans/2026-05-01-auto-update-system.md)

---

## Status

The auto-update system is **code-complete and ready for operator handoff.** All 9 phases of the plan plus three follow-up review cycles plus a final-review fix have landed on `feat/auto-update-system`. Test counts at HEAD:

- **Rust:** 86/86 pass · `cargo clippy --all-targets -- -D warnings` clean
- **TypeScript:** 256/256 pass across 24 files · `tsc --noEmit` clean
- **Vite build:** succeeds
- **Workflow YAML:** parses cleanly · manifest composer `bash -n` clean
- **Dev-pubkey CI guard:** verified to fire correctly against current `tauri.conf.json` (locks the release until rotation)

Code review at HEAD (`1628bda`) found two critical gaps in the original plan execution (no auto-check cadence, silent save destruction on load failure) — both fixed in `1628bda`. The branch is now a coherent, internally consistent v0.2.0 ready to tag once you complete the manual operator steps below.

---

## Two operator tasks before the v0.2.0 tag

### Task 10 — production keypair + GitHub secrets + pubkey rotation

The branch currently embeds a **development-only minisign pubkey** (key ID `2A43CC33F3FB57BB`) in `src-tauri/tauri.conf.json`. The corresponding private key lives at `/tmp/swiftee-dev-keys/dev.key` on the implementer's machine — **not** suitable for production. The CI's `validate-versions` job will refuse any release while the dev pubkey is in place (it's a hard guard with three failure modes: empty, non-base64, dev-key-embedded).

You need to generate a fresh production keypair, register the secrets in GitHub Actions, and replace the embedded pubkey.

#### 1. Generate the production keypair (one-time, offline)

Run on a clean local machine that's NOT shared and NOT a CI runner:

```bash
mkdir -p ~/.tauri
npx tauri signer generate -w ~/.tauri/swiftiequiz.key
```

The CLI will prompt for a password — **choose a strong one** and DO NOT reuse it. Two files appear:

- `~/.tauri/swiftiequiz.key` — encrypted private key
- `~/.tauri/swiftiequiz.key.pub` — public key (single line, base64-encoded)

Print the contents of the `.pub` file:

```bash
cat ~/.tauri/swiftiequiz.key.pub
```

#### 2. Store the private key + password securely

| Where | What |
|---|---|
| 1Password (or your password manager) | Create an entry titled "Swiftie Quiz minisign private key (production)". Attach the contents of `~/.tauri/swiftiequiz.key` as a Document and store the password in the entry's password field. |
| Sealed offline backup (recommended) | Print a paper QR of the `.key` file contents OR copy it to a USB stick stored in a physical safe. **Hobby projects often skip this step. The result is permanent loss of update-signing capability if the dev machine dies.** Don't skip it. |

**If the production key is ever lost or compromised**, recovery requires shipping a new app version with a new pubkey embedded and reaching existing users out-of-band (the same hop as the v0.1.0 → v0.2.0 migration). There is no in-app pubkey rotation. Treat this key like the most security-critical credential in your release process.

#### 3. Register GitHub Actions secrets

Visit `https://github.com/SatanshuMishra/project-swiftee/settings/secrets/actions` and create two repository secrets:

| Secret name | Value |
|---|---|
| `TAURI_SIGNING_PRIVATE_KEY` | The full contents of `~/.tauri/swiftiequiz.key`. Paste as-is — multi-line is fine, GitHub handles it. |
| `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | The password you chose at generation time. |

Both secrets are referenced in `.github/workflows/release.yml` `build-macos` and `build-windows` jobs' `env:` blocks. They are masked in workflow logs by GitHub Actions automatically.

#### 4. Replace the dev pubkey in `tauri.conf.json`

Edit `src-tauri/tauri.conf.json`. Find:

```json
"plugins": {
  "updater": {
    ...
    "pubkey": "<dev pubkey ending in 2A43CC33F3FB57BB...>",
    ...
```

Replace the `pubkey` value with the **single-line** content of `~/.tauri/swiftiequiz.key.pub`. The whole file is a base64-encoded string; paste it verbatim.

Verify the dev-pubkey guard now passes:

```bash
node -e '
  const conf = require("./src-tauri/tauri.conf.json");
  const pk = conf?.plugins?.updater?.pubkey ?? "";
  if (!pk || pk.length < 64) { console.error("EMPTY"); process.exit(1); }
  const decoded = Buffer.from(pk, "base64").toString("utf8");
  if (decoded.includes("2A43CC33F3FB57BB")) { console.error("DEV_KEY"); process.exit(1); }
  console.log("PASSED");
'
```

Expected output: `PASSED` and exit 0. If you see `DEV_KEY`, the rotation didn't take. If you see `EMPTY`, the pubkey field is blank or malformed.

Verify the build still works:

```bash
cd src-tauri && cargo check
cd .. && npm run build
```

#### 5. Commit the rotation

```bash
git add src-tauri/tauri.conf.json
git commit -m "chore: rotate minisign pubkey to production keypair

Replaces the development placeholder pubkey (key ID 2A43CC33F3FB57BB,
generated locally during Phase 3 implementation) with the production
pubkey. The corresponding private key is stored in 1Password and
registered as the TAURI_SIGNING_PRIVATE_KEY GitHub Actions secret.

The CI dev-pubkey guard now passes."
```

**Do not push to `main`** — this commit lands on `feat/auto-update-system` alongside the rest of the work. The push happens via PR merge, after which you tag (Task 27).

---

### Task 27 — tag, swap-test, publish

After the rotation lands and the branch is merged to `main` (or you cherry-pick the rotation onto whatever release branch you use):

#### 1. Tag and push

```bash
git checkout main
git pull origin main
git tag v0.2.0
git push origin v0.2.0
```

This triggers `.github/workflows/release.yml`:

- **`validate-versions`** asserts `package.json`, `Cargo.toml`, `tauri.conf.json`, the git tag, and `CHANGELOG.md` all align on `0.2.0`. The dev-pubkey guard runs.
- **`build-macos`** (Apple Silicon) and **`build-windows`** (x86_64) build in parallel. `tauri-action` injects the signing key, builds bundles + `.sig` files, and uploads to a Draft GitHub release.
- **`publish-manifest`** downloads both bundles' artifacts, runs `.github/scripts/compose-manifest.sh` to produce `latest.json` from the `.sig` files + the `## [0.2.0]` section of `CHANGELOG.md`, uploads `latest.json` as a release asset, and emits SLSA Build L2 provenance attestations.

Watch the run:
```bash
gh run watch
```

Total runtime ≈ 15–25 minutes (most of which is rust-cache-aware builds; first run is slower).

If any job fails, fix the cause locally, push a fix commit + a new tag (e.g. `v0.2.0-rc.2`), and try again. The `concurrency` block in the workflow ensures re-pushed tags queue rather than race.

#### 2. Manual swap-test before publishing

The release stays as **Draft** after CI completes. **Do not** flip it to Published until you've verified the upgrade actually works on real machines. The plan calls for THREE swap-tests:

##### macOS swap-test

1. On an Apple Silicon Mac with the existing v0.1.0 manually-distributed `.dmg` installed, open the app. Play one round so an achievement unlocks (verify it appears in Cat Gallery).
2. Quit the app.
3. Download the new `Swiftie Quiz_0.2.0_aarch64.dmg` from the Draft release page.
4. Mount the DMG. Drag "Swiftie Quiz" to Applications. Finder asks "Replace existing version?" — choose **Replace**.
5. Launch from Applications. Click through the Gatekeeper "Open Anyway" prompt (per `docs/INSTALL.md`).
6. **Verify the achievement is still unlocked** (Cat Gallery).
7. **Verify the "Welcome back" toast appears** at the bottom of the window with copy mentioning the migration.

##### Windows swap-test

1. On a Windows 10/11 x86_64 machine with v0.1.0 installed, open the app, play one round, quit.
2. Run the new `Swiftie Quiz_0.2.0_x64-setup.exe` from the Draft release. Click through SmartScreen.
3. NSIS detects the prior install, uninstalls v0.1.0 binaries, installs v0.2.0.
4. Launch from Start menu.
5. **Verify the achievement is still unlocked + "Welcome back" toast appears.**

##### Updater self-test

This is the test that v0.2.0 itself can be updated by a future v0.2.1 (or whatever comes next). Skip for the very first updater-aware release — there's no prior in-app updater to upgrade *from*. For subsequent releases:

1. Install the previously-published version on a third machine.
2. Open the app. Wait ~1.5 seconds — the auto-check fires automatically.
3. The corner badge should appear. Click it.
4. Modal opens with release notes. Click **Download**. Watch progress.
5. Click **Install & Restart**. App quits, installer runs, app relaunches.
6. Confirm the new version is running and save data is intact.

##### If a swap-test fails

Edit the CHANGELOG with the bug reason, delete the Draft release (`gh release delete v0.2.0 --yes`), revert the version-bump commit on `main`, fix forward, re-tag. Treat each attempt as a fresh release.

#### 3. Publish the release

After all three swap-tests pass:

```bash
gh release edit v0.2.0 --draft=false
```

This is what makes `https://github.com/SatanshuMishra/project-swiftee/releases/latest/download/latest.json` resolve to the new manifest. Existing v0.2.0+ users will see the update on their next 6-hour auto-check cycle (or sooner if they're freshly launching the app).

**Note:** the very first v0.2.0 release does not reach existing v0.1.0 users automatically — those users need an out-of-band notification (whatever channel you used to distribute v0.1.0). This is the "one-time hop" documented in spec §10. From v0.2.0 forward, every future update flows through the in-app updater.

#### 4. Notify existing v0.1.0 users out-of-band

Whatever channel you originally used to share the v0.1.0 `.dmg` and `.exe` (email, DM, group chat, etc.), send a short note pointing to:

```
https://github.com/SatanshuMishra/project-swiftee/releases/tag/v0.2.0
```

Include a one-line reassurance:
> Your achievements, stats, and settings will be preserved automatically. See [INSTALL.md](https://github.com/SatanshuMishra/project-swiftee/blob/main/docs/INSTALL.md) for first-install warnings (the macOS Gatekeeper / Windows SmartScreen click-through is the same as v0.1.0).

---

## What the branch contains (28 commits)

```
1628bda fix: wire auto-check cadence + guard against load failure overwrite
28c9b55 release: bump version to 0.2.0
3570325 docs: README with system requirements, install link, updates posture
237b04a docs: INSTALL.md with first-launch walkthroughs
4873e48 docs: CHANGELOG with v0.2.0 entry
23ec74e ci: harden release pipeline (multi-bundle guard, empty-pubkey, concurrency)
c3d7583 fix(ci): compose-manifest extractor uses literal-prefix match
edef421 ci: 4-job release DAG with manifest + SLSA provenance + dev-pubkey guard
8500f89 refactor: apply Phase 6 review polish
67b2bc2 feat: 'Welcome back' toast on first launch after migration
7a7e7ff fix: from_version is Option<u32> to disambiguate missing-version
e168a15 refactor: apply Phase 5 review follow-ups
d001dba feat: Settings adds Updates and Backups sections
615e988 feat: mount UpdateBadge and UpdateModal in App
252a959 feat: UpdateModal component (release notes + DL/Install actions)
cf6309a feat: UpdateBadge component (corner update indicator)
aca2279 refactor(useUpdater): apply Phase 4 review polish
1df3032 feat: persist skipVersion and remindLater into GameProgress
e61944c feat: useUpdater hook with FSM bridging plugin to store
990b6ce feat: add updaterState slice to gameStore
798770c feat: add updater state machine + LoadResult types
c930162 feat: register tauri-plugin-updater with downgrade defense
bb1776c feat: configure tauri-plugin-updater + bundle settings
95baa84 chore: add tauri-plugin-updater dependency
d7ec160 feat: add UpdaterState to GameProgress (schema v3)
b768764 fix: apply Phase 1 code-review follow-ups
85c6a71 docs: handoff for paused auto-update implementation (older pause doc; superseded by this one)
d3aff08 refactor: extract storage logic into dedicated module
```

## Known v1 simplifications (deliberate, documented)

These are NOT bugs — the spec explicitly accepts them:

1. **Markdown release notes render as plain `<pre>`** in `UpdateModal` (no markdown lib).
2. **No "Open save folder" button** in Settings → Backups (would need `tauri-plugin-shell`).
3. **No "Open release page" button** on install error (same reason).
4. **No "Install on next quit" button** (would need an app-lifecycle hook).
5. **No focus trap in modal** — only Escape close.
6. **Toast utility is direct DOM injection** (single-call surface today).
7. **Pre-existing ESLint v9 flat-config migration is separate tech debt** (`npm run lint` fails; `tsc --noEmit` is clean).

## Pre-existing risks (NOT introduced by this branch — but worth knowing about)

- **`npm run lint` fails** because the project hasn't migrated to ESLint v9's flat-config. Verified by the Phase 9 implementer (the same failure exists at any commit on the branch). The CI workflow (`release.yml`) doesn't run lint, so it doesn't block the release. Worth fixing before public v1.0.
- **The save-data corruption recovery path** is now visible to users via the "Couldn't load your save — Settings → Backups" toast (`usePersistence.ts`), but the user must manually navigate to Settings → Backups to restore. A more automated recovery (auto-restore the most recent valid backup) is a future improvement.

## Reviewer-suggested future hardening (deferred, non-blocking)

From the final review:

1. **SHA-pin third-party GitHub Actions** in `release.yml` (currently uses floating major-tags like `tauri-apps/tauri-action@v0`). Recommend pinning to specific SHAs and bumping deliberately via Dependabot or Renovate. Useful before public v1.0.
2. **Cancel during downloading** does not abort the in-flight `pendingUpdate.download(...)` Promise. Resolved progress events after cancel could update state. Add a generation counter to `useUpdater`'s `ctx` to drop stale resolutions.
3. **`compose-manifest.sh` literal-prefix match** could match `## [0.2` against `## [0.20.0]`. Tightening to require trailing `]` or whitespace would be one-line defensive.
4. **Privacy disclosure copy** could be even more specific (e.g., document the User-Agent string, mention IP/timestamp visibility to GitHub). Current copy is accurate; could be more transparent.

## Final verdict

Once Task 10 (keypair rotation) and Task 27 (tag + swap-test + publish) are done, **v0.2.0 is shippable**. The architecture is clean, the tests are real, the migration story is sound, the security model is documented and verifiable. From v0.3.0+ this becomes a normal release-train workflow — write CHANGELOG entry, bump versions, tag, swap-test, publish.

The first hop (v0.1.0 → v0.2.0) is the only out-of-band one. After that, the in-app updater handles everything.

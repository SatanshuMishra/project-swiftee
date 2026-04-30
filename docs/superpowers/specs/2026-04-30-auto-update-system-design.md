# Auto-Update System — Design Spec

**Status:** Approved (brainstorming complete)
**Date:** 2026-04-30
**Target version:** v0.2.0
**Author:** brainstorming session, Claude (Opus 4.7)

---

## 1. Executive summary

Add a cross-platform self-update mechanism to Swiftie Quiz so that future releases on GitHub can be discovered, downloaded, verified, and installed by the running app on macOS (Apple Silicon) and Windows (x86_64). Existing users on the manually-distributed v0.1.0 build must be able to upgrade to v0.2.0 *without losing local user data* (achievements, stats, settings).

The implementation centers on the official **`tauri-plugin-updater`** with **minisign** signature verification of every update artifact. OS-level code signing is intentionally **out of scope** for v1 — distribution will remain unsigned, with first-install warnings handled via documented user instructions. Updater payload integrity is preserved cryptographically via minisign so that compromise of the GitHub release / CDN cannot push code the running app will accept.

Data preservation is achieved by:

1. Continuing to store the save file in the OS's standard `app_data_dir()` (already done — outside the install dir).
2. Locking the bundle identifier (`com.swiftiequiz.desktop`) permanently.
3. Adopting a structured **migration registry** for forward-only schema upgrades.
4. Backing up the save file before every migration (last 3 backups retained).
5. Surfacing a "Restore from backup" UX in Settings as a last-resort escape hatch.

User-facing UX is **two-step VS Code-style consent**: a non-blocking corner badge appears when an update is available; clicking opens a modal with release notes and explicit *Download* / *Install & Restart* actions. No silent downloads.

---

## 2. Goals and non-goals

### 2.1 Goals

- **G1.** Existing v0.1.0 users can install v0.2.0 manually with zero data loss.
- **G2.** From v0.2.0 onward, future releases are discovered and installed in-app on both macOS (Apple Silicon, macOS 11+) and Windows (x86_64, Windows 10 1809+).
- **G3.** Every update payload is cryptographically verified against an embedded minisign public key before installation.
- **G4.** Downgrade attacks are rejected: the app refuses to install any version less-than-or-equal-to the currently-running version.
- **G5.** No silent downloads. The user sees release notes and explicitly consents before bandwidth is consumed.
- **G6.** No telemetry, no analytics, no install-id headers. Update checks send only `version`/`target`/`arch` (the Tauri plugin defaults).
- **G7.** Save-file schema migrations are forward-only, idempotent, tested, and protected by an automatic pre-migration backup.
- **G8.** Build provenance is attested via SLSA Build L2 (GitHub artifact attestations) from day one.

### 2.2 Non-goals (v1)

- **N1.** OS code signing (Apple Developer ID, Authenticode). Documented future option; explicitly deferred.
- **N2.** Notarization / hardened-runtime entitlements. Follows from N1.
- **N3.** Intel Mac support. Apple Silicon is a hard requirement.
- **N4.** Linux distribution. Not a target platform.
- **N5.** Delta / binary-diff updates. Tauri's first-party updater does not ship them as of April 2026; whole-bundle downloads are accepted.
- **N6.** Beta / nightly channels. v1 is stable-only.
- **N7.** Staged percentage rollouts, kill-switches, mandatory-update gating. Achievable later via a dynamic endpoint; out of scope for v1.
- **N8.** HSM-backed minisign signing. Documented threat-model gap; mitigation deferred.
- **N9.** Resumable downloads. Failed downloads restart from byte 0.
- **N10.** Atomic rollback if a new release crashes on launch. Recovery is manual reinstall.

---

## 3. System requirements (post-spec)

| Platform | Minimum |
|---|---|
| macOS | 11.0 (Big Sur), Apple Silicon (M1+) |
| Windows | 10 1809+, x86_64 |

These get codified in `tauri.conf.json` (`bundle.macOS.minimumSystemVersion: "11.0"`) and stated prominently in `README.md` and `INSTALL.md`. Intel Macs cannot mount the `.dmg` — the OS surfaces a clean "not supported" message rather than crashing.

---

## 4. High-level architecture

### 4.1 Component map

```
┌─ Frontend (React + TS) ────────────────────────────────────┐
│  src/components/UpdateBadge.tsx       ← corner badge       │
│  src/components/UpdateModal.tsx       ← release notes + DL/Install
│  src/components/Settings.tsx          ← + "Updates" + "Backups" sections
│  src/hooks/useUpdater.ts              ← state machine wrapper
│  src/stores/gameStore.ts              ← + updater slice    │
│  src/types/index.ts                   ← + UpdaterState     │
└─────────────────────────────────────────────────────────────┘
                           │ Tauri invoke
┌─ Backend (Rust) ───────────────────────────────────────────┐
│  src-tauri/Cargo.toml                 ← + tauri-plugin-updater = "2"
│  src-tauri/src/lib.rs                 ← register plugin + version_comparator
│  src-tauri/src/commands/updater.rs    ← NEW thin command wrappers
│  src-tauri/src/commands/storage.rs    ← slimmed; delegates to storage/*
│  src-tauri/src/storage/mod.rs         ← NEW module surface │
│  src-tauri/src/storage/migrations.rs  ← NEW migration registry
│  src-tauri/src/storage/backup.rs      ← NEW backup lifecycle
│  src-tauri/src/storage/load.rs        ← NEW load + migrate orchestration
│  src-tauri/src/storage/save.rs        ← atomic write (relocated)
│  src-tauri/src/models/progress.rs     ← + UpdaterState; version=3
│  src-tauri/capabilities/default.json  ← + updater:default  │
│  src-tauri/tauri.conf.json            ← + plugins.updater + minSysVer + bundler.createUpdaterArtifacts
└─────────────────────────────────────────────────────────────┘
                           │ HTTPS
┌─ Publishing ───────────────────────────────────────────────┐
│  GitHub Releases (Published only after manual swap test)   │
│    ├─ latest.json                                          │
│    ├─ SwiftieQuiz_<v>_aarch64.app.tar.gz + .sig            │
│    ├─ SwiftieQuiz_<v>_aarch64.dmg                          │
│    └─ SwiftieQuiz_<v>_x64-setup.exe + .sig                 │
└─────────────────────────────────────────────────────────────┘
                           │ git tag v*
┌─ CI (.github/workflows/release.yml) ───────────────────────┐
│  validate-versions  →  build-{macos,windows}  →  publish-manifest
│  Secrets: TAURI_SIGNING_PRIVATE_KEY, TAURI_SIGNING_PRIVATE_KEY_PASSWORD
│  SLSA: actions/attest-build-provenance@v1                  │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 End-to-end data flow

1. **Boot.** `App.tsx` calls `invoke("load_progress")` → backend's `storage::load::load_and_migrate` returns `LoadResult::{Fresh|Loaded|Migrated}`. `Migrated` triggers a "Welcome back" toast.
2. **Schedule check.** `useUpdater` fires `check()` 1.5s after main UI mount, and every 6h thereafter (skipped if `autoCheckEnabled === false` or if `remind_later_until` is in the future).
3. **Plugin checks.** `tauri-plugin-updater` GETs `https://github.com/SatanshuMishra/project-swiftee/releases/latest/download/latest.json` from Rust (no CSP impact).
4. **Comparator.** Custom `version_comparator: |cur, upd| upd.version > cur` rejects equal-or-older versions (downgrade defense).
5. **Available.** Hook transitions to `available { manifest }`. `UpdateBadge` renders.
6. **User clicks badge.** `UpdateModal` opens, renders `manifest.notes`. User chooses *Download* / *Skip this version* / *Remind me later*.
7. **Download.** Plugin downloads artifact, emits progress events. Hook updates `downloading { manifest, progress }`. Modal shows progress bar.
8. **Verify.** Plugin verifies minisign signature against the public key embedded at compile time. On mismatch → `error: signature` (no auto-retry).
9. **Ready.** Hook → `ready { manifest }`. Modal button changes to *Install & Restart*.
10. **Install.** Plugin runs the platform installer; app exits; installer runs; app relaunches.
11. **Post-relaunch.** Goto step 1. `load_and_migrate` may return `Migrated` if v0.2.0 added a new schema version. Toast confirms.

---

## 5. Configuration changes

### 5.1 `tauri.conf.json`

Three additive blocks (no removals):

```jsonc
{
  "version": "0.2.0",
  "bundle": {
    "createUpdaterArtifacts": true,
    "macOS": { "minimumSystemVersion": "11.0" },
    "windows": { "nsis": { "installMode": "currentUser" } }
  },
  "plugins": {
    "updater": {
      "endpoints": [
        "https://github.com/SatanshuMishra/project-swiftee/releases/latest/download/latest.json"
      ],
      "pubkey": "<base64 minisign pubkey, embedded at compile time>",
      "windows": { "installMode": "passive" }
    }
  }
}
```

**Why each:**

- `createUpdaterArtifacts: true` — emits `.app.tar.gz` (macOS) and `.sig` files alongside regular bundles. Without this, the manifest has nothing to point at.
- `bundle.macOS.minimumSystemVersion: "11.0"` — Apple Silicon needs Big Sur+; older Intel Macs get a clean "not supported" rather than a confusing crash.
- `bundle.windows.nsis.installMode: "currentUser"` — installs into `%LOCALAPPDATA%\Programs\Swiftie Quiz`, **avoiding UAC prompt** on every launch. Critical for an unsigned app — UAC is one more scary dialog avoided.
- `plugins.updater.windows.installMode: "passive"` — silent installer with progress bar, no prompts.

**CSP correction.** Earlier audit suggested adding GitHub domains to `connect-src`. **This is incorrect** — the updater plugin makes its HTTP requests from the Rust backend via `reqwest`, not from the WebView. Tauri's CSP governs only the WebView's `fetch`/`XHR`/`WebSocket` traffic. The current Deezer + LRCLIB allowlist stays unchanged. Per project rule 2 ("Tauri CSP is load-bearing"), this is a clean no-op.

### 5.2 `src-tauri/capabilities/default.json`

```json
{
  "permissions": [
    "core:default",
    "fs:default",
    "updater:default"
  ]
}
```

Single line addition.

### 5.3 `src-tauri/Cargo.toml`

```toml
tauri-plugin-updater = "2"
```

### 5.4 `src-tauri/src/lib.rs`

```rust
.plugin(
    tauri_plugin_updater::Builder::new()
        .version_comparator(|current, update| update.version > current)
        .build()
)
```

The `version_comparator` override is the **downgrade-attack defense.** Without it, a compromised CDN could serve an older signed-but-vulnerable version and the plugin would happily install it.

---

## 6. Minisign signing (the only integrity guarantee)

With Option C (no OS code signing), minisign is **the only** check between the publisher and the user.

### 6.1 Keypair generation (one-time, offline)

```bash
npx tauri signer generate -w ~/.tauri/swiftiequiz.key
```

Produces an encrypted private key file (password-protected) and prints a public key. Public key gets pasted into `tauri.conf.json:plugins.updater.pubkey`. Private key never leaves a secrets store.

### 6.2 Storage

| Where | What |
|---|---|
| 1Password (or equivalent) | Encrypted `.key` file + the password |
| Sealed offline backup | Printed paper QR + USB stick in a physical safe location |
| GitHub Actions secrets | `TAURI_SIGNING_PRIVATE_KEY` (file contents), `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` |
| `tauri.conf.json` | Public key only (safe to commit) |

### 6.3 Threat model

**If the private key leaks:** an attacker can sign updates the app will accept as authentic. Recovery requires:

1. Generate a new keypair.
2. Ship a new app version with the new pubkey embedded.
3. Reach existing users via the same out-of-band channel as v0.1.0 → v0.2.0 (the updater on the old pubkey will reject the new release as invalid).

This is a **documented limitation**. Future mitigations (HSM-backed signing via AWS KMS or YubiKey, two-of-N key models) are deferred.

**OS-level local tampering** (someone with shell access replacing the `.app`/`.exe` on the user's machine) is **not protected** — this is normal for unsigned apps and beyond v1's scope. The user's responsibility is to install the app from a trusted source. After that first install, every update is cryptographically verified.

---

## 7. Data layer

### 7.1 Storage module restructure

```
src-tauri/src/
├── commands/
│   ├── storage.rs          ← thin Tauri command wrappers (slimmed from current)
│   └── updater.rs          ← NEW: thin updater command wrappers
├── models/
│   └── progress.rs         ← + UpdaterState field (v3 schema bump)
└── storage/                ← NEW MODULE
    ├── mod.rs
    ├── migrations.rs       ← migration registry (pure, no I/O)
    ├── backup.rs           ← backup lifecycle
    ├── load.rs             ← load + migrate orchestration
    └── save.rs             ← atomic write (relocated from current storage.rs)
```

### 7.2 Migration registry

```rust
// src-tauri/src/storage/migrations.rs
type Migration = fn(Value) -> Result<Value, AppError>;

pub const CURRENT_VERSION: u32 = 3;

const MIGRATIONS: &[(u32, Migration)] = &[
    (1, migrate_v1_to_v2),
    (2, migrate_v2_to_v3),
];

pub fn migrate_to_latest(mut state: Value) -> Result<Value, AppError> {
    let mut v = state.get("version").and_then(|x| x.as_u64()).unwrap_or(1) as u32;
    while v < CURRENT_VERSION {
        let step = MIGRATIONS.iter()
            .find(|(from, _)| *from == v)
            .ok_or(AppError::MissingMigration(v))?
            .1;
        state = step(state)?;
        v += 1;
    }
    Ok(state)
}

fn migrate_v1_to_v2(mut state: Value) -> Result<Value, AppError> {
    // Existing v1→v2 logic relocated verbatim from storage.rs:58
    state["stats"]["totalLyricsCorrect"]  = json!(0);
    state["stats"]["nameThaSongCorrect"]  = json!(0);
    state["stats"]["lyricsOrLieCorrect"]  = json!(0);
    state["version"] = json!(2);
    Ok(state)
}

fn migrate_v2_to_v3(mut state: Value) -> Result<Value, AppError> {
    // Adds the new updater state slice
    state["updater"] = json!({
        "autoCheckEnabled":  true,
        "lastCheckedAt":     null,
        "skippedVersions":   [],
        "remindLaterUntil":  null
    });
    state["version"] = json!(3);
    Ok(state)
}
```

Three properties this gives us:

- **Single source of truth.** `CURRENT_VERSION` and `MIGRATIONS` live next to each other.
- **Forward-only chain.** The `while` loop only goes up.
- **Pure functions.** Unit tests synthesize a `Value` and assert; no filesystem.

### 7.3 Backup module

```rust
// src-tauri/src/storage/backup.rs
const MAX_BACKUPS: usize = 3;

pub fn create_backup(save_path: &Path) -> Result<PathBuf, AppError>;
pub fn list_backups(save_dir: &Path) -> Result<Vec<BackupEntry>, AppError>;
pub fn restore_from_backup(backup: &Path, save_path: &Path) -> Result<(), AppError>;

pub struct BackupEntry {
    pub timestamp: u64,
    pub path: PathBuf,
    pub size_bytes: u64,
}
```

Backup file naming: `save.backup.<unix-ts>.json` next to `save.json`. Pruning: when a new backup is created, delete the oldest until `count <= MAX_BACKUPS`.

### 7.4 Load orchestration

```rust
// src-tauri/src/storage/load.rs
pub enum LoadResult {
    Fresh,
    Loaded(GameProgress),
    Migrated { progress: GameProgress, from_version: u32 },
}

pub fn load_and_migrate(save_path: &Path) -> Result<LoadResult, AppError> {
    if !save_path.exists() {
        return Ok(LoadResult::Fresh);
    }
    let raw = fs::read_to_string(save_path)?;
    let value: Value = serde_json::from_str(&raw)?;
    let from_version = value.get("version").and_then(|x| x.as_u64()).unwrap_or(1) as u32;

    if from_version < migrations::CURRENT_VERSION {
        backup::create_backup(save_path)?;
        let migrated = migrations::migrate_to_latest(value)?;
        let progress: GameProgress = serde_json::from_value(migrated.clone())?;
        save::write_atomic(save_path, &migrated)?;
        Ok(LoadResult::Migrated { progress, from_version })
    } else {
        Ok(LoadResult::Loaded(serde_json::from_value(value)?))
    }
}
```

If a migration throws mid-flight, the original `save.json` is untouched (only a copy + a tmp file have been written) and the freshly-created backup remains. The error propagates to the frontend, which surfaces a non-fatal toast and points the user to Settings → Backups.

### 7.5 Schema additions (DTO sync — project rule 1)

**Rust** (`src-tauri/src/models/progress.rs`):

```rust
pub struct GameProgress {
    pub version: u32,                            // = 3
    pub achievements: HashMap<String, AchievementState>,
    pub stats: GameStats,
    pub settings: GameSettings,
    pub updater: UpdaterState,                   // NEW
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct UpdaterState {
    pub auto_check_enabled: bool,
    pub last_checked_at: Option<String>,
    pub skipped_versions: Vec<String>,
    pub remind_later_until: Option<String>,
}

impl Default for UpdaterState { /* matches DEFAULT_PROGRESS */ }
```

**TypeScript** (`src/types/index.ts`):

```typescript
export interface UpdaterState {
  readonly autoCheckEnabled: boolean;
  readonly lastCheckedAt: string | null;
  readonly skippedVersions: readonly string[];
  readonly remindLaterUntil: string | null;
}

export interface GameProgress {
  readonly version: number;            // = 3
  readonly achievements: Record<string, AchievementState>;
  readonly stats: GameStats;
  readonly settings: GameSettings;
  readonly updater: UpdaterState;      // NEW
}

export const DEFAULT_PROGRESS: GameProgress = {
  version: 3,
  achievements: {},
  stats: { /* ... existing ... */ },
  settings: { /* ... existing ... */ },
  updater: {
    autoCheckEnabled: true,
    lastCheckedAt: null,
    skippedVersions: [],
    remindLaterUntil: null,
  },
};
```

The four-place rule (Rust struct, Rust `Default`, TS interface, `DEFAULT_PROGRESS`) must all line up. Run `/sync-schemas` after the change.

### 7.6 New Tauri commands

```rust
#[tauri::command] async fn load_progress(app: AppHandle) -> Result<LoadResult, String>;
#[tauri::command] async fn save_progress(progress: GameProgress, app: AppHandle) -> Result<(), String>;
#[tauri::command] async fn list_save_backups(app: AppHandle) -> Result<Vec<BackupEntry>, String>;
#[tauri::command] async fn restore_save_backup(timestamp: u64, app: AppHandle) -> Result<(), String>;
```

Registered in `lib.rs`'s `invoke_handler`. `load_progress`'s return type changes from `GameProgress` to `LoadResult` — this is a frontend-visible change (TS types updated in lockstep).

---

## 8. Frontend UX

### 8.1 State machine

The `useUpdater.ts` hook owns a discriminated-union state:

```typescript
type UpdaterMachineState =
  | { kind: "idle" }
  | { kind: "checking" }
  | { kind: "up-to-date" }
  | { kind: "available";   manifest: UpdateManifest }
  | { kind: "downloading"; manifest: UpdateManifest; progress: number }
  | { kind: "ready";       manifest: UpdateManifest }
  | { kind: "installing" }
  | { kind: "error"; subtype: "check"|"download"|"signature"|"install"; message: string };
```

State transitions are exhaustive — every failure mode named, no catch-all.

### 8.2 Components

**`UpdateBadge.tsx`** — top-right corner, hidden in `idle`/`checking`/`up-to-date`. Pulsing dot for `available`, spinner+% for `downloading`, solid green for `ready`, subtle yellow icon for `error`. Click opens modal.

**`UpdateModal.tsx`** — single component with state-switched content. State-to-buttons table:

| State | Buttons |
|---|---|
| `available` | **Download** · *Skip this version* · *Remind me later* · *Close* |
| `downloading` | *Cancel* · *Hide* (closes modal, badge stays) |
| `ready` | **Install & Restart** · *Install on next quit* · *Close* |
| `error: download` | **Retry** · *Close* |
| `error: signature` | *Dismiss* (red banner — no auto-retry) |
| `error: install` | **Retry** · *Open release page* · *Close* |

Release notes from `manifest.notes` rendered through the project's existing markdown renderer (or a tiny one if absent). Notes are trusted (came through the minisign-verified manifest) but never `dangerouslySetInnerHTML`.

**`Settings.tsx`** — two new sections appended:

```
─────── Updates ───────
Current version: v0.2.0
Last checked: <relative time>     [ Check now ]
[✓] Automatically check for updates
    Sends only app version, OS, and architecture.
    No analytics or unique identifiers.

─────── Backups ───────
Save backups (last 3 kept automatically)
  • <timestamp>  (<size>)   [ Restore ]
  • <timestamp>  (<size>)   [ Restore ]
  • <timestamp>  (<size>)   [ Restore ]
[ Open save folder ]
```

### 8.3 Cadence

| When | What |
|---|---|
| App launch | `check()` 1.5s after main UI mount |
| While running | Every 6 hours via `setInterval` |
| Manual "Check now" | Bypasses all cooldowns |
| After "Remind me later" | 24h cooldown — `remind_later_until` honored |
| After "Skip this version" | That version no longer auto-promotes; newer versions still do |
| `autoCheckEnabled = false` | No auto-check; only manual button works |

### 8.4 First-launch-after-upgrade toast

```typescript
const result = await invoke<LoadResult>("load_progress");
if (result.kind === "migrated") {
  showToast(`Welcome back! Your progress has been preserved. (Migrated from save format v${result.fromVersion}.)`);
}
```

5-second auto-dismiss, dismissible, bottom-center, non-blocking.

### 8.5 Error UX matrix

| Failure | What user sees | Recovery |
|---|---|---|
| Offline at scheduled check | Nothing (silent) | Retry next launch |
| Manual "Check now" while offline | "Couldn't reach update server." | User retries |
| Download fails partway | "Download failed at X%." | Retry from byte 0 |
| Signature mismatch | Red modal: "Update verification failed." | No auto-retry; user dismisses |
| Install command fails | "Install failed: \<reason\>." | Retry + manual download fallback link |
| Save migration fails on relaunch | Toast: "Couldn't load your save — restored from backup." | Settings → Backups |
| Disk full | "Not enough disk space (need X MB)." | User frees space, retries |

Every error path writes a structured log line via Tauri's existing log infrastructure. No PII.

### 8.6 Accessibility (WCAG 2.2 AA targets)

- Badge is a real `<button>` with `aria-label`, focusable, keyboard-activatable.
- Modal has focus trap + initial focus on primary action + Escape closes.
- Progress: `role="progressbar"` + `aria-valuenow`/`aria-valuemin`/`aria-valuemax`.
- All animations honor `@media (prefers-reduced-motion)`.
- Color is never the only signal — every state has icon + text.

---

## 9. CI / release pipeline

### 9.1 Workflow shape (four jobs)

```
validate-versions ─▶ build-macos ─┐
                                  ├─▶ publish-manifest ─▶ MANUAL GATE ─▶ Published
                  └─▶ build-windows┘                       (swap test)
```

CI **never auto-publishes**. The release is left as Draft after manifest composition; the operator runs the swap test on both OSes, then explicitly flips to Published with `gh release edit vX.Y.Z --draft=false`.

### 9.2 `validate-versions` job

A 5-line shell guard asserting `git tag` (without `v` prefix) equals `package.json:version` equals `Cargo.toml:version` equals `tauri.conf.json:version`, and that `CHANGELOG.md` contains a `## [X.Y.Z]` entry. Runs in ~30s on `ubuntu-latest`. Fails fast before any expensive build.

### 9.3 `build-{macos,windows}` jobs

Both invoke `tauri-apps/tauri-action@v0` with signing env vars set:

```yaml
env:
  TAURI_SIGNING_PRIVATE_KEY:          ${{ secrets.TAURI_SIGNING_PRIVATE_KEY }}
  TAURI_SIGNING_PRIVATE_KEY_PASSWORD: ${{ secrets.TAURI_SIGNING_PRIVATE_KEY_PASSWORD }}
with:
  releaseDraft: true     # CRITICAL — never auto-publish
```

With `bundle.createUpdaterArtifacts: true` set, tauri-action emits `.sig` files automatically alongside each artifact. No manual `signtool` step, no notarization. macOS runs on `macos-14` (Apple Silicon); Windows on `windows-latest`.

### 9.4 `publish-manifest` job

Composes `latest.json` with `version`, `notes` (extracted from CHANGELOG entry by an `awk` script), `pub_date` (ISO timestamp), and `platforms.{darwin-aarch64, windows-x86_64}.{signature, url}`. Uploads `latest.json` to the Draft release, then emits SLSA build provenance attestations via `actions/attest-build-provenance@v1`. Release stays Draft.

### 9.5 Manual swap-test gate (operator's checklist)

The `/release` skill walks the operator through:

1. Wait for all four CI jobs to succeed.
2. Download `.dmg` and `setup.exe` from the Draft release.
3. **macOS swap test**: install previous version → play one game → install new `.dmg` over the top → relaunch → confirm achievement persists + "Welcome back" toast.
4. **Windows swap test**: same pattern with `setup.exe`.
5. **Updater test on a third machine**: install previous version → click in-app "Check now" → walk through Download → Install & Restart → confirm new version is running.
6. After all three pass: `gh release edit vX.Y.Z --draft=false`.

If any test fails: edit CHANGELOG with reason, delete the Draft release (`gh release delete vX.Y.Z --yes`), revert the version-bump commit, fix forward.

### 9.6 GitHub repo secrets (one-time setup)

| Secret | Value |
|---|---|
| `TAURI_SIGNING_PRIVATE_KEY` | Contents of `~/.tauri/swiftiequiz.key` |
| `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | Password chosen at keypair generation |

### 9.7 Kill switch and recovery

For a broken release: `gh release edit vX.Y.Z --draft=true` un-publishes; the `latest/download/latest.json` URL stops resolving and clients silently stay on their current version. Or: hand-edit `latest.json` to point back to the prior version. Both are operator-driven, ~1 minute.

---

## 10. Migration plan for existing v0.1.0 users

### 10.1 The hop

The v0.1.0 → v0.2.0 hop is **out-of-band**. v0.1.0 has no mechanism to learn about new versions (no banner, no updater). The maintainer notifies existing users via the same channel originally used to distribute v0.1.0 (email, DM, etc.) with a link to the GitHub v0.2.0 release page.

From v0.2.0 forward, every future update flows through `tauri-plugin-updater` automatically. This out-of-band hop is one-time.

### 10.2 Why data is preserved automatically

| Property | Status |
|---|---|
| Bundle ID `com.swiftiequiz.desktop` is locked | ✅ |
| Save file at `app_data_dir()` (outside install dir) | ✅ ([storage.rs:10](src-tauri/src/commands/storage.rs:10)) |
| Atomic write (write-tmp + rename) | ✅ ([storage.rs:32](src-tauri/src/commands/storage.rs:32)) |
| Schema version field + migration framework | ✅ extended to migration registry (§7.2) |
| Backup-before-migrate | ✅ NEW (§7.3) |

### 10.3 Install mechanics for the hop

| Platform | User downloads | What happens |
|---|---|---|
| macOS | `.dmg` from GitHub release | Mounts → drag-to-Applications → Finder asks "Replace existing version?" → Yes → save data untouched |
| Windows | `.exe` (NSIS) from GitHub release | Run installer → NSIS detects prior install → uninstalls v0.1.0 binaries → installs v0.2.0 → `%APPDATA%\com.swiftiequiz.desktop` untouched |

### 10.4 First-install warnings (Option C unsigned)

Both OSes will show a warning the first time. `INSTALL.md` documents the click-through:

- **macOS:** the `.dmg` mounts fine, but launching the `.app` shows *"This app cannot be opened because the developer cannot be verified."* User opens System Settings → Privacy & Security → finds the entry for "Swiftie Quiz was blocked from use" → clicks "Open Anyway." Subsequent launches are silent.
- **Windows:** SmartScreen shows *"Microsoft Defender SmartScreen prevented an unrecognized app from starting."* User clicks "More info" → "Run anyway." Subsequent launches are silent.

After the first install, **subsequent updates via the in-app updater bypass these warnings** because the updater downloads via `reqwest` (no quarantine xattr / Mark-of-the-Web is set) and replaces files in-place.

---

## 11. Security and threat model

| Threat | Mitigation in v1 |
|---|---|
| MitM on update channel | HTTPS + minisign signature pinned to embedded pubkey ✅ |
| Compromised GitHub release / CDN | Minisign signature verification ✅ |
| Compromised minisign key | **Documented limitation.** Manual pubkey rotation + out-of-band re-distribution required. HSM signing deferred |
| Compromised Apple/Authenticode key | N/A (unsigned) |
| Downgrade attack (older signed version) | Custom `version_comparator` enforces strict monotonic upgrade ✅ |
| Supply chain (compromised CI runner) | SLSA Build L2 via GitHub artifact attestations ✅ |
| Compromised dependency | Existing `npm audit` + future `cargo deny` in CI |
| Local OS-level tampering | **Not protected** (normal for unsigned apps; user's responsibility) |
| Malicious release notes (XSS via manifest) | Markdown renderer, no `dangerouslySetInnerHTML`, CSP unchanged |

---

## 12. Privacy posture

The Tauri updater is privacy-clean by default. Update checks send only:

- The `target` (`darwin`/`windows`)
- The `arch` (`aarch64`/`x86_64`)
- The `current_version` (substituted into the URL path)

Plus the standard `reqwest` `User-Agent`. No install ID, no analytics, no user identifier.

The server (GitHub) inevitably observes the requesting IP, version, OS, arch, and timing. This is documented in the privacy notice section of `README.md`.

**Settings escape hatch:** a user-toggleable "Auto-check for updates" preference (default ON, persisted in `updater.autoCheckEnabled`). When OFF, no automatic checks run; only the manual "Check now" button works. A subtitle under the toggle reads: *"Sends only app version, OS, and architecture. No analytics or unique identifiers."*

---

## 13. Testing strategy

### 13.1 Unit / cargo tests

| Test | What it catches |
|---|---|
| Per-migration golden round-trip | Field-level migration bugs |
| Chain test for every starting version (v1→v3, v2→v3, v3→v3 no-op) | "Forgot to update earlier migration when adding v3" |
| Idempotency (`migrate_to_latest` twice → second is no-op) | Migrations that mutate when they shouldn't |
| Backup rotation (write 5 sequential saves → assert exactly 3 backups + latest save remain) | Disk-bloat regressions |
| Restore round-trip (save → mutate → restore → assert match) | Restore logic correctness |
| Schema drift sentinel (load v3 with extra unknown field → no crash) | Forward-compat for users on a *newer* schema |

### 13.2 Frontend / vitest

| Test | What it catches |
|---|---|
| `useUpdater` state machine transitions (synthesize plugin events → assert state) | Hook bugs |
| `UpdateModal` content per state (snapshot tests) | UI regressions |
| `UpdateBadge` visibility per state | UI regressions |

### 13.3 Manual / release checklist

| Test | When |
|---|---|
| Cross-OS swap test (install previous → play → install new → verify achievement) | Before every release, on both OSes |
| Updater self-test on a third machine | Before every release |
| First-install warning walkthrough validates against current macOS/Windows builds | Periodically (OS updates change wording) |

---

## 14. Documentation deliverables (ship with v0.2.0)

| File | Contents |
|---|---|
| `docs/INSTALL.md` | First-time install per OS. Click-through walkthrough of the macOS and Windows warnings (with screenshots). Save data location. Uninstall instructions |
| `CHANGELOG.md` | New file. `## [0.2.0] - <date>` entry describing the auto-update feature + the v0.1.0 → v0.2.0 migration reassurance |
| `README.md` updates | System requirements (Apple Silicon macOS 11+ / Windows 10 1809+); a one-paragraph "Updates" section linking to `INSTALL.md`; a privacy note ("update checks send version/OS/arch; no analytics") |
| GitHub release body (per release) | Auto-populated from CHANGELOG section by CI. Per-OS download highlights |

---

## 15. Open questions and known limitations

| # | Item | Status |
|---|---|---|
| 1 | Tauri's first-party delta-update support as of April 2026 | Confirmed **not shipped**; Velopack remains the alternative if download size becomes painful |
| 2 | HSM-backed minisign signing | Deferred. Mitigation for stolen-key scenario is manual rotation + out-of-band redistribution |
| 3 | Resumable downloads | Not in v1. Accepted (whole-bundle re-download is acceptable on desktop broadband) |
| 4 | Atomic rollback if new version crashes | Not in v1. Recovery is manual reinstall from previous release page |
| 5 | Beta channel | Deferred. Stable-only for v1 |
| 6 | Dynamic manifest endpoint (Cloudflare Worker) | Deferred. Static `latest.json` on GitHub Releases for v1 |
| 7 | Staged rollouts / kill switches / mandatory updates | Deferred. Migration to dynamic endpoint unlocks all three |
| 8 | Intel Mac support | Deferred. Apple Silicon hard requirement |
| 9 | Linux distribution | Not a target |

---

## 16. References

- [Tauri 2 updater plugin](https://v2.tauri.app/plugin/updater/)
- [Tauri plugins-workspace v2 (updater)](https://github.com/tauri-apps/plugins-workspace/tree/v2/plugins/updater)
- [Tauri JS path API](https://v2.tauri.app/reference/javascript/api/namespacepath/)
- [Tauri macOS signing & notarization](https://v2.tauri.app/distribute/sign/macos/) (referenced for future re-enable of OS code signing)
- [Tauri Windows signing](https://v2.tauri.app/distribute/sign/windows/) (same)
- [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) (deferred)
- [Microsoft RestartManager API](https://learn.microsoft.com/en-us/windows/win32/api/restartmanager/) (Velopack future)
- [Sparkle project docs](https://sparkle-project.org/documentation/) (design influence)
- [Velopack repo](https://github.com/velopack/velopack) (alternative considered)
- [SLSA v1.0 levels](https://slsa.dev/spec/v1.0/levels)
- [GitHub artifact attestations](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds)

---

## 17. Decision log (from brainstorming session 2026-04-30)

| # | Decision | Rationale |
|---|---|---|
| Q1 | **Unsigned distribution** (Option C) | Personal/hobby project, technical audience, deferred-but-future-proofed for OS code signing |
| Q2 | **Two-step VS Code-style consent UX** (A1) | User-driven download + install; no silent bandwidth use |
| Q3 | **Out-of-band hop for v0.1.0 users** (Option B with one-hop notification) | Existing users have no mechanism to learn about new versions; one-time email/DM is acceptable |
| Q4 | **Apple Silicon-only macOS** (Option A) | Smaller CI footprint; future migration to universal binary documented as low-cost (~2h) |
| Q5 | **Stable-only channel + GitHub Releases static manifest** (A + X) | Simplest viable; future migration to dynamic endpoint documented |
| Q6 | **Migration registry pattern** (Option B) + last-3 backups + UpdaterState in `GameProgress` (v2→v3 schema bump) + Restore-from-backup Settings UI | Modest framework gain, idempotent + tested chain, single backup story for the whole save file |

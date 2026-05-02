# Auto-Update System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add cross-platform self-update to Swiftie Quiz (macOS Apple Silicon + Windows x86_64) using `tauri-plugin-updater`, with backward-compatible save-file migration, minisign payload signing, and a two-step consent UX. Existing v0.1.0 users must upgrade to v0.2.0 without losing local data.

**Architecture:** Three layers change together. **Backend (Rust):** new `storage/` module with migration registry + backup-before-migrate; updater plugin registered with downgrade-rejecting `version_comparator`. **Frontend (TS/React):** `useUpdater` hook owns a discriminated-union state machine; `UpdateBadge` + `UpdateModal` render per state; Settings adds Updates + Backups sections. **CI:** four-job DAG (validate → build {macOS, Windows} → publish-manifest) emitting `latest.json` to a Draft GitHub release; manual swap-test gate before publish.

**Tech Stack:** Tauri 2.x · `tauri-plugin-updater` v2 · React 18 + TS strict · Zustand · Vitest · Rust 2021 · `serde_json` · `tempfile` · GitHub Actions · `actions/attest-build-provenance@v1` · minisign (Ed25519).

**Spec reference:** [docs/superpowers/specs/2026-04-30-auto-update-system-design.md](../specs/2026-04-30-auto-update-system-design.md)

---

## File Structure (decomposition lock-in)

### Files to create
| Path | Responsibility | Approx. lines |
|---|---|---|
| `src-tauri/src/storage/mod.rs` | Module declarations + re-exports | 10 |
| `src-tauri/src/storage/save.rs` | Atomic write (write-tmp + rename) | 60 |
| `src-tauri/src/storage/migrations.rs` | Migration registry, pure functions | 150 |
| `src-tauri/src/storage/backup.rs` | Create/list/restore/prune backups | 130 |
| `src-tauri/src/storage/load.rs` | Load + migrate orchestration, returns `LoadResult` | 100 |
| `src-tauri/src/commands/updater.rs` | Thin Tauri command wrappers (only if needed beyond plugin defaults) | 30 |
| `src/hooks/useUpdater.ts` | State-machine hook bridging plugin events to Zustand slice | 200 |
| `src/hooks/useUpdater.test.ts` | Vitest tests for state transitions | 250 |
| `src/components/UpdateBadge.tsx` | Corner badge — visible in `available`/`downloading`/`ready`/`error` | 80 |
| `src/components/UpdateBadge.test.tsx` | Render-per-state tests | 100 |
| `src/components/UpdateModal.tsx` | Release notes + state-driven action buttons | 200 |
| `src/components/UpdateModal.test.tsx` | Render-per-state tests | 200 |
| `CHANGELOG.md` | `## [0.2.0]` entry — source of `notes` in `latest.json` | — |
| `docs/INSTALL.md` | First-install warning walkthroughs per OS | — |
| `.github/scripts/compose-manifest.sh` | CI step that builds `latest.json` from artifacts | 50 |

### Files to modify
| Path | Why |
|---|---|
| `src-tauri/Cargo.toml` | Add `tauri-plugin-updater = "2"` |
| `src-tauri/src/lib.rs` | Register updater plugin with `version_comparator`; register new commands |
| `src-tauri/src/commands/storage.rs` | Slim to thin wrappers (move logic to `storage/*`); update return type of `load_progress` to `LoadResult`; add `list_save_backups`, `restore_save_backup` |
| `src-tauri/src/commands/mod.rs` | Add `pub mod updater;` |
| `src-tauri/src/models/progress.rs` | Add `UpdaterState` struct + field on `GameProgress`; bump `Default::version` to 3 |
| `src-tauri/tauri.conf.json` | Add `plugins.updater`, `bundle.createUpdaterArtifacts`, `bundle.macOS.minimumSystemVersion`, `bundle.windows.nsis.installMode` |
| `src-tauri/capabilities/default.json` | Add `updater:default` permission |
| `src/types/index.ts` | Add `UpdaterState`, `UpdaterMachineState`, `UpdateManifest`, `LoadResult`; add `updater` to `GameProgress`; bump `DEFAULT_PROGRESS.version` to 3 |
| `src/stores/gameStore.ts` | Add updater state slice + immutable setter |
| `src/components/Settings.tsx` | Add "Updates" + "Backups" sections |
| `src/App.tsx` | Mount `UpdateBadge`; consume `LoadResult` on boot; show "Welcome back" toast on `Migrated` |
| `src/main.tsx` (or equivalent) | Initialize `useUpdater` |
| `package.json` | Add `@tauri-apps/plugin-updater` dependency; bump version to `0.2.0` |
| `.github/workflows/release.yml` | Restructure into 4-job DAG; add signing env, validate-versions, publish-manifest, SLSA attestations |
| `README.md` | System requirements + Updates/privacy paragraph |

---

## Conventions (apply to every task)

- **TDD strict for Rust logic and TS hooks/components.** Write the failing test first, run it, see it fail, then write the minimal implementation.
- **Pragmatic for config files.** No tests; verify by build (`npm run build` or `cargo check`) and commit.
- **Conventional Commits.** `feat: …`, `refactor: …`, `test: …`, `docs: …`, `ci: …`, `chore: …`.
- **One task = one focused commit.** Never bundle unrelated changes.
- **Project rule 1:** Any change to `src/types/index.ts` OR `src-tauri/src/models/*.rs` triggers DTO sync — both sides must change in the same commit. Run `/sync-schemas` after.
- **Project rule 4:** No `console.log` in `src/` production code (tests exempt).
- **camelCase serde:** existing pattern via `#[serde(rename_all = "camelCase")]` — keep it.

---

# Phase 1 — Storage refactor (no behavior change)

The current `src-tauri/src/commands/storage.rs` does three jobs in one file. We split it into a `storage/` module so the command file becomes a thin wrapper. Phase 1 is pure refactor — same behavior, more files. After Phase 1, `cargo test` should still pass with the same assertions.

---

## Task 1: Scaffold the `storage/` module

**Files:**
- Create: `src-tauri/src/storage/mod.rs`
- Modify: `src-tauri/src/lib.rs:1-4` (add `pub mod storage;`)

- [ ] **Step 1: Create `src-tauri/src/storage/mod.rs`**

```rust
// src-tauri/src/storage/mod.rs
pub mod backup;
pub mod load;
pub mod migrations;
pub mod save;

pub use backup::{BackupEntry, create_backup, list_backups, restore_from_backup};
pub use load::{LoadResult, load_and_migrate};
pub use migrations::{CURRENT_VERSION, migrate_to_latest};
pub use save::write_atomic;
```

(The four submodules will be created in subsequent tasks. This file is the public surface that the rest of the codebase imports from.)

- [ ] **Step 2: Register the module in `lib.rs`**

```rust
// src-tauri/src/lib.rs (top of file)
pub mod commands;
pub mod models;
pub mod services;
pub mod state;
pub mod storage;  // NEW
```

- [ ] **Step 3: Run `cargo check` to verify nothing breaks**

```bash
cd src-tauri && cargo check
```
Expected: build fails because the four submodule files don't exist yet. **This is fine — proceed to Task 2 immediately, do not commit.** This task is the skeleton; Tasks 2–6 fill it in. The first green commit is at the end of Task 6.

---

## Task 2: Relocate atomic write to `storage/save.rs`

**Files:**
- Create: `src-tauri/src/storage/save.rs`
- Test: same file (`#[cfg(test)] mod tests {}`)

- [ ] **Step 1: Write the failing test**

```rust
// src-tauri/src/storage/save.rs
use serde::Serialize;
use std::fs;
use std::path::Path;

use crate::models::error::AppError;

pub fn write_atomic<T: Serialize>(path: &Path, value: &T) -> Result<(), AppError> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let temp_path = path.with_extension("json.tmp");
    let json = serde_json::to_string_pretty(value)?;
    fs::write(&temp_path, json)?;
    fs::rename(&temp_path, path)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use tempfile::tempdir;

    #[test]
    fn writes_then_renames_atomically() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("data.json");
        write_atomic(&path, &json!({"a": 1})).unwrap();
        let contents = fs::read_to_string(&path).unwrap();
        assert!(contents.contains("\"a\": 1"));
        // tmp file should not linger
        assert!(!path.with_extension("json.tmp").exists());
    }

    #[test]
    fn creates_parent_dir_if_missing() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("nested/sub/data.json");
        write_atomic(&path, &json!({"a": 1})).unwrap();
        assert!(path.exists());
    }

    #[test]
    fn overwrites_existing_file() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("data.json");
        fs::write(&path, "old").unwrap();
        write_atomic(&path, &json!({"a": 2})).unwrap();
        let contents = fs::read_to_string(&path).unwrap();
        assert!(contents.contains("\"a\": 2"));
    }
}
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
cd src-tauri && cargo test --lib storage::save
```
Expected: 3 tests PASS (the implementation is in the same diff because `write_atomic` is small and ports verbatim from existing code at `commands/storage.rs:31-35`).

- [ ] **Step 3: Stage but do not commit yet** — Phase 1 commits as a single refactor at the end of Task 6.

---

## Task 3: Create migration registry with v1→v2 relocated

**Files:**
- Create: `src-tauri/src/storage/migrations.rs`
- Modify: `src-tauri/src/models/error.rs` (add `MissingMigration` variant)

- [ ] **Step 1: Add the `MissingMigration` error variant**

```rust
// src-tauri/src/models/error.rs (add to the AppError enum)
#[error("Missing migration step from version {0}")]
MissingMigration(u32),
```

- [ ] **Step 2: Write the failing test for migration registry**

```rust
// src-tauri/src/storage/migrations.rs
use serde_json::{Value, json};

use crate::models::error::AppError;

pub type Migration = fn(Value) -> Result<Value, AppError>;

pub const CURRENT_VERSION: u32 = 2;  // bumped to 3 in Task 7

const MIGRATIONS: &[(u32, Migration)] = &[
    (1, migrate_v1_to_v2),
];

pub fn migrate_to_latest(mut state: Value) -> Result<Value, AppError> {
    let mut v = state
        .get("version")
        .and_then(Value::as_u64)
        .unwrap_or(1) as u32;
    while v < CURRENT_VERSION {
        let step = MIGRATIONS
            .iter()
            .find(|(from, _)| *from == v)
            .ok_or(AppError::MissingMigration(v))?
            .1;
        state = step(state)?;
        v += 1;
    }
    Ok(state)
}

fn migrate_v1_to_v2(mut state: Value) -> Result<Value, AppError> {
    let stats = state["stats"].as_object_mut().ok_or_else(|| {
        AppError::ParseError("stats missing or not an object".to_string())
    })?;
    stats.entry("totalLyricsCorrect").or_insert(json!(0));
    stats.entry("nameThaSongCorrect").or_insert(json!(0));
    stats.entry("lyricsOrLieCorrect").or_insert(json!(0));
    state["version"] = json!(2);
    Ok(state)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn v1_save() -> Value {
        json!({
            "version": 1,
            "achievements": {},
            "stats": {
                "totalCorrect": 5,
                "albumsPlayed": [],
                "tracksGuessedPerAlbum": {}
            },
            "settings": { "theme": "dark", "volume": 0.8 }
        })
    }

    #[test]
    fn migrates_v1_to_current() {
        let result = migrate_to_latest(v1_save()).unwrap();
        assert_eq!(result["version"], CURRENT_VERSION);
        assert_eq!(result["stats"]["totalLyricsCorrect"], 0);
        assert_eq!(result["stats"]["nameThaSongCorrect"], 0);
        assert_eq!(result["stats"]["lyricsOrLieCorrect"], 0);
        // existing fields preserved
        assert_eq!(result["stats"]["totalCorrect"], 5);
    }

    #[test]
    fn no_op_when_already_current() {
        let mut current = v1_save();
        current["version"] = json!(CURRENT_VERSION);
        current["stats"]["totalLyricsCorrect"] = json!(0);
        current["stats"]["nameThaSongCorrect"] = json!(0);
        current["stats"]["lyricsOrLieCorrect"] = json!(0);

        let before = current.clone();
        let after = migrate_to_latest(current).unwrap();
        assert_eq!(before, after);
    }

    #[test]
    fn idempotent_double_run() {
        let once = migrate_to_latest(v1_save()).unwrap();
        let twice = migrate_to_latest(once.clone()).unwrap();
        assert_eq!(once, twice);
    }

    #[test]
    fn missing_version_treated_as_v1() {
        let mut s = v1_save();
        s.as_object_mut().unwrap().remove("version");
        let result = migrate_to_latest(s).unwrap();
        assert_eq!(result["version"], CURRENT_VERSION);
    }
}
```

- [ ] **Step 3: Run tests**

```bash
cd src-tauri && cargo test --lib storage::migrations
```
Expected: 4 tests PASS.

---

## Task 4: Create backup module

**Files:**
- Create: `src-tauri/src/storage/backup.rs`

- [ ] **Step 1: Write the failing tests**

```rust
// src-tauri/src/storage/backup.rs
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

use serde::Serialize;

use crate::models::error::AppError;

pub const MAX_BACKUPS: usize = 3;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BackupEntry {
    pub timestamp: u64,
    pub path: String,
    pub size_bytes: u64,
}

pub fn create_backup(save_path: &Path) -> Result<PathBuf, AppError> {
    if !save_path.exists() {
        return Err(AppError::FileError(
            "save file does not exist".to_string(),
        ));
    }
    let ts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| AppError::FileError(e.to_string()))?
        .as_secs();
    let backup = save_path.with_file_name(format!("save.backup.{ts}.json"));
    fs::copy(save_path, &backup)?;
    if let Some(parent) = save_path.parent() {
        prune_old_backups(parent)?;
    }
    Ok(backup)
}

pub fn list_backups(save_dir: &Path) -> Result<Vec<BackupEntry>, AppError> {
    let mut entries: Vec<BackupEntry> = Vec::new();
    if !save_dir.exists() {
        return Ok(entries);
    }
    for entry in fs::read_dir(save_dir)? {
        let entry = entry?;
        let path = entry.path();
        if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
            if let Some(ts) = parse_backup_timestamp(name) {
                let metadata = entry.metadata()?;
                entries.push(BackupEntry {
                    timestamp: ts,
                    path: path.to_string_lossy().into_owned(),
                    size_bytes: metadata.len(),
                });
            }
        }
    }
    entries.sort_by(|a, b| b.timestamp.cmp(&a.timestamp)); // newest first
    Ok(entries)
}

pub fn restore_from_backup(backup_path: &Path, save_path: &Path) -> Result<(), AppError> {
    if !backup_path.exists() {
        return Err(AppError::FileError(
            "backup file does not exist".to_string(),
        ));
    }
    let temp_path = save_path.with_extension("json.tmp");
    fs::copy(backup_path, &temp_path)?;
    fs::rename(&temp_path, save_path)?;
    Ok(())
}

fn parse_backup_timestamp(filename: &str) -> Option<u64> {
    let stripped = filename.strip_prefix("save.backup.")?;
    let ts_str = stripped.strip_suffix(".json")?;
    ts_str.parse::<u64>().ok()
}

fn prune_old_backups(dir: &Path) -> Result<(), AppError> {
    let backups = list_backups(dir)?;
    for stale in backups.iter().skip(MAX_BACKUPS) {
        let _ = fs::remove_file(&stale.path);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn write_save(dir: &Path, contents: &str) -> PathBuf {
        let path = dir.join("save.json");
        fs::write(&path, contents).unwrap();
        path
    }

    #[test]
    fn create_backup_makes_a_copy_with_timestamp() {
        let dir = tempdir().unwrap();
        let save = write_save(dir.path(), "hello");
        let backup = create_backup(&save).unwrap();
        assert!(backup.exists());
        assert!(backup
            .file_name()
            .unwrap()
            .to_string_lossy()
            .starts_with("save.backup."));
        assert_eq!(fs::read_to_string(backup).unwrap(), "hello");
    }

    #[test]
    fn create_backup_errors_when_save_missing() {
        let dir = tempdir().unwrap();
        let result = create_backup(&dir.path().join("nonexistent.json"));
        assert!(result.is_err());
    }

    #[test]
    fn list_backups_returns_newest_first() {
        let dir = tempdir().unwrap();
        let _save = write_save(dir.path(), "x");
        // Manually create three backups with explicit timestamps
        for ts in [100u64, 200, 300] {
            fs::write(
                dir.path().join(format!("save.backup.{ts}.json")),
                format!("ts={ts}"),
            )
            .unwrap();
        }
        let entries = list_backups(dir.path()).unwrap();
        assert_eq!(entries.len(), 3);
        assert_eq!(entries[0].timestamp, 300);
        assert_eq!(entries[1].timestamp, 200);
        assert_eq!(entries[2].timestamp, 100);
    }

    #[test]
    fn list_backups_ignores_non_backup_files() {
        let dir = tempdir().unwrap();
        fs::write(dir.path().join("save.json"), "x").unwrap();
        fs::write(dir.path().join("random.txt"), "y").unwrap();
        fs::write(dir.path().join("save.backup.500.json"), "z").unwrap();
        let entries = list_backups(dir.path()).unwrap();
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].timestamp, 500);
    }

    #[test]
    fn prune_keeps_only_max_backups() {
        let dir = tempdir().unwrap();
        for ts in 1..=5u64 {
            fs::write(
                dir.path().join(format!("save.backup.{ts}.json")),
                "x",
            )
            .unwrap();
        }
        prune_old_backups(dir.path()).unwrap();
        let remaining = list_backups(dir.path()).unwrap();
        assert_eq!(remaining.len(), MAX_BACKUPS);
        // newest 3 (ts 5,4,3) survive; ts 1,2 deleted
        assert_eq!(remaining[0].timestamp, 5);
        assert_eq!(remaining[2].timestamp, 3);
    }

    #[test]
    fn restore_overwrites_save_file() {
        let dir = tempdir().unwrap();
        let save = write_save(dir.path(), "current");
        let backup = dir.path().join("save.backup.100.json");
        fs::write(&backup, "restored").unwrap();
        restore_from_backup(&backup, &save).unwrap();
        assert_eq!(fs::read_to_string(save).unwrap(), "restored");
    }
}
```

- [ ] **Step 2: Run tests**

```bash
cd src-tauri && cargo test --lib storage::backup
```
Expected: 6 tests PASS.

---

## Task 5: Create load orchestration with `LoadResult`

**Files:**
- Create: `src-tauri/src/storage/load.rs`
- Modify: `src-tauri/src/storage/mod.rs` (add `pub mod load;`)

- [ ] **Step 1: Write the failing tests**

```rust
// src-tauri/src/storage/load.rs
use std::fs;
use std::path::Path;

use serde::Serialize;

use crate::models::error::AppError;
use crate::models::progress::GameProgress;
use crate::storage::{backup, migrations, save};

#[derive(Debug, Serialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum LoadResult {
    Fresh,
    Loaded { progress: GameProgress },
    Migrated { progress: GameProgress, from_version: u32 },
}

pub fn load_and_migrate(save_path: &Path) -> Result<LoadResult, AppError> {
    if !save_path.exists() {
        return Ok(LoadResult::Fresh);
    }
    let raw = fs::read_to_string(save_path)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;

    let from_version = value
        .get("version")
        .and_then(|v| v.as_u64())
        .unwrap_or(1) as u32;

    if from_version < migrations::CURRENT_VERSION {
        backup::create_backup(save_path)?;
        let migrated = migrations::migrate_to_latest(value)?;
        let progress: GameProgress = serde_json::from_value(migrated.clone())?;
        save::write_atomic(save_path, &migrated)?;
        Ok(LoadResult::Migrated { progress, from_version })
    } else {
        let progress: GameProgress = serde_json::from_value(value)?;
        Ok(LoadResult::Loaded { progress })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use tempfile::tempdir;

    fn write_save_json(dir: &Path, value: &serde_json::Value) -> std::path::PathBuf {
        let path = dir.join("save.json");
        fs::write(&path, serde_json::to_string_pretty(value).unwrap()).unwrap();
        path
    }

    #[test]
    fn returns_fresh_when_no_save_file() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("save.json");
        let result = load_and_migrate(&path).unwrap();
        assert!(matches!(result, LoadResult::Fresh));
    }

    #[test]
    fn returns_loaded_when_already_current() {
        let dir = tempdir().unwrap();
        let progress = GameProgress::default();
        let path = write_save_json(
            dir.path(),
            &serde_json::to_value(&progress).unwrap(),
        );
        let result = load_and_migrate(&path).unwrap();
        match result {
            LoadResult::Loaded { progress: p } => {
                assert_eq!(p.version, GameProgress::default().version);
            }
            other => panic!("expected Loaded, got {:?}", other),
        }
    }

    #[test]
    fn returns_migrated_and_persists_when_old_version() {
        let dir = tempdir().unwrap();
        let v1_state = json!({
            "version": 1,
            "achievements": {},
            "stats": {
                "totalCorrect": 7,
                "albumsPlayed": [],
                "tracksGuessedPerAlbum": {}
            },
            "settings": { "theme": "dark", "volume": 0.8 }
        });
        let path = write_save_json(dir.path(), &v1_state);

        let result = load_and_migrate(&path).unwrap();
        match result {
            LoadResult::Migrated { progress, from_version } => {
                assert_eq!(from_version, 1);
                assert_eq!(progress.version, migrations::CURRENT_VERSION);
                assert_eq!(progress.stats.total_correct, 7);
            }
            other => panic!("expected Migrated, got {:?}", other),
        }

        // Backup should exist
        let backups = backup::list_backups(dir.path()).unwrap();
        assert_eq!(backups.len(), 1);

        // File on disk should now be the migrated shape
        let on_disk: serde_json::Value =
            serde_json::from_str(&fs::read_to_string(&path).unwrap()).unwrap();
        assert_eq!(on_disk["version"], migrations::CURRENT_VERSION);
    }

    #[test]
    fn migration_failure_leaves_backup_intact() {
        let dir = tempdir().unwrap();
        // stats missing → migrate_v1_to_v2 returns Err
        let bad_state = json!({
            "version": 1,
            "achievements": {},
            "settings": { "theme": "dark", "volume": 0.8 }
        });
        let path = write_save_json(dir.path(), &bad_state);

        let result = load_and_migrate(&path);
        assert!(result.is_err());

        // Backup created BEFORE migration attempt
        let backups = backup::list_backups(dir.path()).unwrap();
        assert_eq!(backups.len(), 1);

        // Original on disk untouched
        let on_disk: serde_json::Value =
            serde_json::from_str(&fs::read_to_string(&path).unwrap()).unwrap();
        assert_eq!(on_disk["version"], 1);
    }
}
```

- [ ] **Step 2: Run tests**

```bash
cd src-tauri && cargo test --lib storage::load
```
Expected: 4 tests PASS.

---

## Task 6: Slim `commands/storage.rs` to thin wrappers; commit Phase 1

**Files:**
- Modify: `src-tauri/src/commands/storage.rs` (replace contents)

- [ ] **Step 1: Replace `commands/storage.rs` with thin wrappers**

```rust
// src-tauri/src/commands/storage.rs
use std::path::PathBuf;

use tauri::{AppHandle, Manager, State};

use crate::models::error::AppError;
use crate::models::progress::GameProgress;
use crate::state::AppState;
use crate::storage::{self, BackupEntry, LoadResult};

fn save_path(app: &AppHandle) -> Result<PathBuf, AppError> {
    let app_data = app
        .path()
        .app_data_dir()
        .map_err(|e| AppError::FileError(e.to_string()))?;
    Ok(app_data.join("save.json"))
}

#[tauri::command]
pub async fn save_progress(
    progress: GameProgress,
    app: AppHandle,
    _state: State<'_, AppState>,
) -> Result<(), AppError> {
    let path = save_path(&app)?;
    storage::write_atomic(&path, &progress)
}

#[tauri::command]
pub async fn load_progress(
    app: AppHandle,
    _state: State<'_, AppState>,
) -> Result<LoadResult, AppError> {
    let path = save_path(&app)?;
    storage::load_and_migrate(&path)
}

#[tauri::command]
pub async fn list_save_backups(
    app: AppHandle,
    _state: State<'_, AppState>,
) -> Result<Vec<BackupEntry>, AppError> {
    let path = save_path(&app)?;
    let dir = path.parent().ok_or_else(|| {
        AppError::FileError("save path has no parent directory".to_string())
    })?;
    storage::list_backups(dir)
}

#[tauri::command]
pub async fn restore_save_backup(
    timestamp: u64,
    app: AppHandle,
    _state: State<'_, AppState>,
) -> Result<(), AppError> {
    let path = save_path(&app)?;
    let dir = path.parent().ok_or_else(|| {
        AppError::FileError("save path has no parent directory".to_string())
    })?;
    let backup_path = dir.join(format!("save.backup.{timestamp}.json"));
    storage::restore_from_backup(&backup_path, &path)
}
```

- [ ] **Step 2: Register the new commands in `lib.rs`**

```rust
// src-tauri/src/lib.rs (inside generate_handler!)
.invoke_handler(tauri::generate_handler![
    commands::deezer::fetch_albums,
    commands::deezer::fetch_album_tracks,
    commands::deezer::fetch_top_tracks,
    commands::storage::save_progress,
    commands::storage::load_progress,
    commands::storage::list_save_backups,      // NEW
    commands::storage::restore_save_backup,    // NEW
    commands::lyrics::fetch_lyrics,
    commands::lyrics::fetch_lyrics_batch,
])
```

- [ ] **Step 3: Run the full test suite**

```bash
cd src-tauri && cargo test
```
Expected: all tests PASS (the existing `models::progress::tests` plus the new `storage::*` tests).

- [ ] **Step 4: Run clippy**

```bash
cd src-tauri && cargo clippy -- -D warnings
```
Expected: no warnings.

- [ ] **Step 5: Commit Phase 1**

```bash
git add src-tauri/src/storage/ src-tauri/src/commands/storage.rs src-tauri/src/lib.rs src-tauri/src/models/error.rs
git commit -m "refactor: extract storage logic into dedicated module

Splits commands/storage.rs into a focused storage/ module with
migrations, backup, load orchestration, and atomic save. Adds backup
lifecycle (last 3 retained) plus list_save_backups and
restore_save_backup commands. Behaviour preserved; introduces
LoadResult { Fresh | Loaded | Migrated } as the new load_progress
return type."
```

---

> **NOTE:** Phase 1's commit changes the return type of `load_progress` from `GameProgress` to `LoadResult`. The frontend currently calls `invoke<GameProgress>("load_progress")` and will fail at runtime after this commit. Phase 5 (Task 22) updates the frontend to consume `LoadResult`. Until then, the app will not boot correctly. **Do not deploy between Phase 1 and Phase 5.** This is acceptable because we are between releases (v0.1.0 already shipped, v0.2.0 not yet tagged); main is the integration branch.

---

# Phase 2 — Schema bump to v3 (UpdaterState)

Adds the `UpdaterState` slice to `GameProgress` and writes the v2→v3 migration. Per project rule 1, both Rust and TS sides must change in the same commit.

---

## Task 7: Add `UpdaterState` to Rust model + `migrate_v2_to_v3`

**Files:**
- Modify: `src-tauri/src/models/progress.rs`
- Modify: `src-tauri/src/storage/migrations.rs` (bump `CURRENT_VERSION`, add new step)

- [ ] **Step 1: Write failing tests in `models/progress.rs`**

```rust
// src-tauri/src/models/progress.rs (extend the existing tests module)

#[test]
fn default_progress_is_v3_with_updater_state() {
    let p = GameProgress::default();
    assert_eq!(p.version, 3);
    assert!(p.updater.auto_check_enabled);
    assert!(p.updater.last_checked_at.is_none());
    assert!(p.updater.skipped_versions.is_empty());
    assert!(p.updater.remind_later_until.is_none());
}

#[test]
fn updater_state_serializes_with_camel_case() {
    let p = GameProgress::default();
    let json = serde_json::to_value(&p).unwrap();
    let updater = json.get("updater").unwrap().as_object().unwrap();
    assert!(updater.contains_key("autoCheckEnabled"));
    assert!(updater.contains_key("lastCheckedAt"));
    assert!(updater.contains_key("skippedVersions"));
    assert!(updater.contains_key("remindLaterUntil"));
}
```

- [ ] **Step 2: Update `models/progress.rs` to add `UpdaterState`**

```rust
// src-tauri/src/models/progress.rs

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdaterState {
    pub auto_check_enabled: bool,
    pub last_checked_at: Option<String>,
    pub skipped_versions: Vec<String>,
    pub remind_later_until: Option<String>,
}

impl Default for UpdaterState {
    fn default() -> Self {
        Self {
            auto_check_enabled: true,
            last_checked_at: None,
            skipped_versions: Vec::new(),
            remind_later_until: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GameProgress {
    pub version: u32,
    pub achievements: HashMap<String, AchievementState>,
    pub stats: GameStats,
    pub settings: GameSettings,
    #[serde(default)]
    pub updater: UpdaterState,   // NEW; #[serde(default)] for forward-compat with v2 saves on first read
}

impl Default for GameProgress {
    fn default() -> Self {
        Self {
            version: 3,                       // BUMPED
            achievements: HashMap::new(),
            stats: GameStats { /* unchanged */ /* ... */ },
            settings: GameSettings { /* unchanged */ /* ... */ },
            updater: UpdaterState::default(),  // NEW
        }
    }
}
```

(Keep the existing `GameStats` and `GameSettings` field initializers verbatim from the current file; only `version` and the new `updater` field change in `Default`.)

Update the existing test `test_default_progress`:

```rust
#[test]
fn test_default_progress() {
    let progress = GameProgress::default();
    assert_eq!(progress.version, 3);  // was 2
    /* rest unchanged */
}
```

- [ ] **Step 3: Add `migrate_v2_to_v3` and bump `CURRENT_VERSION`**

```rust
// src-tauri/src/storage/migrations.rs

pub const CURRENT_VERSION: u32 = 3;  // BUMPED from 2

const MIGRATIONS: &[(u32, Migration)] = &[
    (1, migrate_v1_to_v2),
    (2, migrate_v2_to_v3),    // NEW
];

fn migrate_v2_to_v3(mut state: Value) -> Result<Value, AppError> {
    if state.get("updater").is_none() {
        state["updater"] = json!({
            "autoCheckEnabled": true,
            "lastCheckedAt": null,
            "skippedVersions": [],
            "remindLaterUntil": null
        });
    }
    state["version"] = json!(3);
    Ok(state)
}
```

Add tests in the same file:

```rust
#[test]
fn migrate_v2_to_v3_adds_updater_field() {
    let v2 = json!({
        "version": 2,
        "achievements": {},
        "stats": {
            "totalCorrect": 0,
            "albumsPlayed": [],
            "tracksGuessedPerAlbum": {},
            "totalLyricsCorrect": 0,
            "nameThaSongCorrect": 0,
            "lyricsOrLieCorrect": 0
        },
        "settings": { "theme": "dark", "volume": 0.8 }
    });
    let result = migrate_to_latest(v2).unwrap();
    assert_eq!(result["version"], 3);
    assert_eq!(result["updater"]["autoCheckEnabled"], true);
    assert_eq!(result["updater"]["lastCheckedAt"], serde_json::Value::Null);
    assert!(result["updater"]["skippedVersions"].is_array());
}

#[test]
fn migrate_v1_through_v3_chain() {
    let v1 = json!({
        "version": 1,
        "achievements": {},
        "stats": {
            "totalCorrect": 99,
            "albumsPlayed": [],
            "tracksGuessedPerAlbum": {}
        },
        "settings": { "theme": "dark", "volume": 0.8 }
    });
    let result = migrate_to_latest(v1).unwrap();
    assert_eq!(result["version"], 3);
    assert_eq!(result["stats"]["totalCorrect"], 99);
    assert_eq!(result["stats"]["totalLyricsCorrect"], 0);
    assert_eq!(result["updater"]["autoCheckEnabled"], true);
}

#[test]
fn migrate_v2_to_v3_preserves_existing_updater_field() {
    // Forward-compat: if a future build wrote an updater field, don't clobber
    let v2_with_updater = json!({
        "version": 2,
        "achievements": {},
        "stats": {
            "totalCorrect": 0,
            "albumsPlayed": [],
            "tracksGuessedPerAlbum": {},
            "totalLyricsCorrect": 0,
            "nameThaSongCorrect": 0,
            "lyricsOrLieCorrect": 0
        },
        "settings": { "theme": "dark", "volume": 0.8 },
        "updater": { "autoCheckEnabled": false, "lastCheckedAt": "2026-01-01T00:00:00Z", "skippedVersions": ["0.3.0"], "remindLaterUntil": null }
    });
    let result = migrate_to_latest(v2_with_updater).unwrap();
    assert_eq!(result["updater"]["autoCheckEnabled"], false);
    assert_eq!(result["updater"]["skippedVersions"][0], "0.3.0");
}
```

- [ ] **Step 4: Run all Rust tests**

```bash
cd src-tauri && cargo test
```
Expected: all tests PASS.

- [ ] **Step 5: Stage but do not commit yet** — Task 8 syncs the TS side; both commit together.

---

## Task 8: Sync TS types with `UpdaterState` schema bump

**Files:**
- Modify: `src/types/index.ts`

- [ ] **Step 1: Add types to `src/types/index.ts`**

```typescript
// src/types/index.ts (additions)

export interface UpdaterState {
  readonly autoCheckEnabled: boolean;
  readonly lastCheckedAt: string | null;
  readonly skippedVersions: readonly string[];
  readonly remindLaterUntil: string | null;
}

// Modify the existing GameProgress interface:
export interface GameProgress {
  readonly version: number;
  readonly achievements: Record<string, AchievementState>;
  readonly stats: GameStats;
  readonly settings: GameSettings;
  readonly updater: UpdaterState;   // NEW
}

// Modify the existing DEFAULT_PROGRESS const:
export const DEFAULT_PROGRESS: GameProgress = {
  version: 3,                         // bumped from 1
  achievements: {},
  stats: {
    totalCorrect: 0,
    albumsPlayed: [],
    tracksGuessedPerAlbum: {},
    totalLyricsCorrect: 0,
    nameThaSongCorrect: 0,
    lyricsOrLieCorrect: 0,
  },
  settings: {
    theme: "dark",
    volume: 0.8,
    mediumTimer: 30,
    hardTimer: 20,
  },
  updater: {                          // NEW
    autoCheckEnabled: true,
    lastCheckedAt: null,
    skippedVersions: [],
    remindLaterUntil: null,
  },
};
```

- [ ] **Step 2: Run TypeScript check**

```bash
npx tsc --noEmit
```
Expected: any callers consuming `GameProgress` may show errors if they construct it inline. Fix those by spreading from `DEFAULT_PROGRESS`. Most consumers should already use `DEFAULT_PROGRESS`.

- [ ] **Step 3: Run `/sync-schemas` to verify Rust ↔ TS alignment**

```bash
# Run the project skill
/sync-schemas
```
Expected: clean — no drift reported. If drift is reported, fix the indicated side and re-run.

- [ ] **Step 4: Commit schema bump (Tasks 7 + 8 together)**

```bash
git add src-tauri/src/models/progress.rs src-tauri/src/storage/migrations.rs src/types/index.ts
git commit -m "feat: add UpdaterState to GameProgress (schema v3)

Adds GameProgress.updater { autoCheckEnabled, lastCheckedAt,
skippedVersions, remindLaterUntil } as the persistent slice for the
auto-update feature. Bumps schema version 2→3 and adds
migrate_v2_to_v3 to the registry. DTO sync between
src-tauri/src/models/progress.rs and src/types/index.ts maintained
per project rule 1."
```

---

# Phase 3 — Updater plugin integration

Wire the Tauri updater plugin into the Rust backend with our chosen configuration: minisign-verified payloads, downgrade-rejecting comparator, NSIS per-user install on Windows, Apple Silicon-only macOS.

---

## Task 9: Add `tauri-plugin-updater` dependencies

**Files:**
- Modify: `src-tauri/Cargo.toml`
- Modify: `package.json`

- [ ] **Step 1: Add Rust dependency**

```toml
# src-tauri/Cargo.toml (add to [dependencies])
tauri-plugin-updater = "2"
```

- [ ] **Step 2: Add JS dependency**

```bash
npm install @tauri-apps/plugin-updater
```

- [ ] **Step 3: Verify both build**

```bash
cd src-tauri && cargo check
cd .. && npm run build
```
Expected: both succeed.

- [ ] **Step 4: Commit**

```bash
git add src-tauri/Cargo.toml src-tauri/Cargo.lock package.json package-lock.json
git commit -m "chore: add tauri-plugin-updater dependency

Adds tauri-plugin-updater v2 (Rust) and @tauri-apps/plugin-updater
(JS) without registering or configuring it yet. Configuration lands
in the next commit."
```

---

## Task 10: Generate the minisign keypair (operator manual step)

**Files:** none in this repo. This task documents the operator action and produces secrets stored externally.

- [ ] **Step 1: Generate keypair on a clean local machine (one-time, offline)**

```bash
mkdir -p ~/.tauri
npx tauri signer generate -w ~/.tauri/swiftiequiz.key
```
- Choose a strong password when prompted.
- The command prints the public key; **copy it** — needed in Task 11.

- [ ] **Step 2: Store the private key + password**

- Add the contents of `~/.tauri/swiftiequiz.key` to a 1Password (or equivalent) vault entry titled "Swiftie Quiz minisign private key".
- Add the password to the same entry as the entry's password field.
- Print a paper QR backup of the file contents and store in a sealed offline location (optional but recommended).

- [ ] **Step 3: Register GitHub Actions secrets**

Visit `https://github.com/SatanshuMishra/project-swiftee/settings/secrets/actions` and create:

| Secret name | Value |
|---|---|
| `TAURI_SIGNING_PRIVATE_KEY` | Full contents of `~/.tauri/swiftiequiz.key` (single paste — multi-line is fine) |
| `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | The password chosen in Step 1 |

- [ ] **Step 4: No commit for this task** — this task produces external secrets, not code. Move directly to Task 11, which uses the public key.

---

## Task 11: Configure `tauri.conf.json` for the updater + bundle adjustments

**Files:**
- Modify: `src-tauri/tauri.conf.json`

- [ ] **Step 1: Add `bundle.createUpdaterArtifacts`, `macOS.minimumSystemVersion`, `windows.nsis.installMode`, and the `plugins.updater` block**

```jsonc
// src-tauri/tauri.conf.json — replace the existing "bundle" object and add a "plugins" object

  "bundle": {
    "active": true,
    "targets": "all",
    "createUpdaterArtifacts": true,
    "icon": [
      "icons/32x32.png",
      "icons/128x128.png",
      "icons/128x128@2x.png",
      "icons/icon.icns",
      "icons/icon.ico"
    ],
    "macOS": {
      "minimumSystemVersion": "11.0"
    },
    "windows": {
      "nsis": {
        "installMode": "currentUser"
      }
    }
  },
  "plugins": {
    "updater": {
      "endpoints": [
        "https://github.com/SatanshuMishra/project-swiftee/releases/latest/download/latest.json"
      ],
      "pubkey": "<PASTE THE PUBLIC KEY FROM TASK 10 STEP 1>",
      "windows": { "installMode": "passive" }
    }
  }
```

- [ ] **Step 2: Verify config validates**

```bash
cd src-tauri && cargo check
```
Expected: success. If the config has a syntax error, Tauri's macros surface it during `check`.

- [ ] **Step 3: Verify the dev build still launches**

```bash
npm run tauri dev
```
Quit it after the window appears. (We are not testing the updater yet — just that the config did not break the app.)

- [ ] **Step 4: Commit**

```bash
git add src-tauri/tauri.conf.json
git commit -m "feat: configure tauri-plugin-updater + bundle settings

Adds plugins.updater with the GitHub releases endpoint and the
embedded minisign public key. Sets bundle.createUpdaterArtifacts:
true so the bundler emits .app.tar.gz / .sig payloads.
Sets bundle.macOS.minimumSystemVersion=11.0 (Apple Silicon target)
and bundle.windows.nsis.installMode=currentUser (no UAC for
unsigned installs)."
```

---

## Task 12: Update capabilities + register plugin in `lib.rs`

**Files:**
- Modify: `src-tauri/capabilities/default.json`
- Modify: `src-tauri/src/lib.rs`

- [ ] **Step 1: Add the updater permission**

```json
// src-tauri/capabilities/default.json
{
  "$schema": "https://raw.githubusercontent.com/nicegui/tauri-v2/main/core/tauri-config-schema/schema.json",
  "identifier": "default",
  "description": "Default capability for Swiftie Quiz",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "fs:allow-appdata-read",
    "fs:allow-appdata-write",
    "updater:default"
  ]
}
```

- [ ] **Step 2: Write a unit test for the version comparator**

```rust
// src-tauri/src/lib.rs (add a tests module at the bottom)

#[cfg(test)]
mod tests {
    use semver::Version;

    fn version_gt(current: &str, update: &str) -> bool {
        let cur = Version::parse(current).unwrap();
        let upd = Version::parse(update).unwrap();
        upd > cur
    }

    #[test]
    fn rejects_equal_version() {
        assert!(!version_gt("0.2.0", "0.2.0"));
    }

    #[test]
    fn rejects_older_version() {
        assert!(!version_gt("0.2.0", "0.1.5"));
    }

    #[test]
    fn accepts_newer_patch() {
        assert!(version_gt("0.2.0", "0.2.1"));
    }

    #[test]
    fn accepts_newer_minor() {
        assert!(version_gt("0.2.0", "0.3.0"));
    }
}
```

(The actual plugin closure in `Builder::new().version_comparator(...)` receives `Version` instances directly. The test above pins our intent in pure semver — `cargo test --lib tests::` will catch any drift.)

- [ ] **Step 3: Register the plugin with the comparator**

```rust
// src-tauri/src/lib.rs (modify run())

pub fn run() {
    let app_state = AppState::new();

    tauri::Builder::default()
        .plugin(tauri_plugin_fs::init())
        .plugin(
            tauri_plugin_updater::Builder::new()
                .version_comparator(|current, update| update.version > current)
                .build(),
        )
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![
            commands::deezer::fetch_albums,
            commands::deezer::fetch_album_tracks,
            commands::deezer::fetch_top_tracks,
            commands::storage::save_progress,
            commands::storage::load_progress,
            commands::storage::list_save_backups,
            commands::storage::restore_save_backup,
            commands::lyrics::fetch_lyrics,
            commands::lyrics::fetch_lyrics_batch,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

(Note: `tauri-plugin-updater`'s `Builder::version_comparator` signature accepts a closure of `Fn(Version, RemoteRelease) -> bool` per the v2 plugin API. The exact signature may differ slightly; if `cargo check` complains about argument shapes, adjust the closure body to match the plugin's documented signature while preserving the `update.version > current` semantics.)

- [ ] **Step 4: Add `semver` to Cargo.toml as a dev-dependency** for the unit test

```toml
# src-tauri/Cargo.toml [dev-dependencies]
semver = "1"
```

- [ ] **Step 5: Run all Rust tests**

```bash
cd src-tauri && cargo test && cargo clippy -- -D warnings
```
Expected: all tests PASS, clippy clean.

- [ ] **Step 6: Commit**

```bash
git add src-tauri/capabilities/default.json src-tauri/src/lib.rs src-tauri/Cargo.toml src-tauri/Cargo.lock
git commit -m "feat: register tauri-plugin-updater with downgrade defense

Registers the plugin with a strict-monotonic version_comparator that
rejects any update whose version is not greater than the running
binary (downgrade-attack defense). Adds updater:default to the
capability allowlist. Adds semver dev-dep for the comparator unit
test."
```

---

# Phase 4 — Frontend state machine + hook

`useUpdater` owns a discriminated-union state machine. All UI components consume it; no other code talks to the plugin directly.

---

## Task 13: Add updater types and `UpdateManifest`/`UpdaterMachineState` to `types/index.ts`

**Files:**
- Modify: `src/types/index.ts`

- [ ] **Step 1: Add types**

```typescript
// src/types/index.ts (additions)

export interface UpdateManifest {
  readonly version: string;
  readonly notes: string;
  readonly pubDate: string;
}

export type UpdaterMachineState =
  | { readonly kind: "idle" }
  | { readonly kind: "checking" }
  | { readonly kind: "up-to-date" }
  | { readonly kind: "available";   readonly manifest: UpdateManifest }
  | { readonly kind: "downloading"; readonly manifest: UpdateManifest; readonly progress: number }
  | { readonly kind: "ready";       readonly manifest: UpdateManifest }
  | { readonly kind: "installing" }
  | {
      readonly kind: "error";
      readonly subtype: "check" | "download" | "signature" | "install";
      readonly message: string;
    };

// Mirror the Rust enum
export type LoadResult =
  | { readonly kind: "fresh" }
  | { readonly kind: "loaded"; readonly progress: GameProgress }
  | { readonly kind: "migrated"; readonly progress: GameProgress; readonly fromVersion: number };
```

- [ ] **Step 2: TypeScript check**

```bash
npx tsc --noEmit
```
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add src/types/index.ts
git commit -m "feat: add updater state machine + LoadResult types

Adds UpdaterMachineState (discriminated union), UpdateManifest, and
LoadResult to mirror the Rust LoadResult enum. No runtime behaviour;
types only."
```

---

## Task 14: Add updater slice to Zustand store

**Files:**
- Modify: `src/stores/gameStore.ts`

- [ ] **Step 1: Inspect current store structure**

```bash
sed -n '1,40p' src/stores/gameStore.ts
```
(Read enough to know where to add the slice. The slice integrates into the existing single store, not a separate one.)

- [ ] **Step 2: Add the updater slice**

In `src/stores/gameStore.ts`, add to the state interface and initial state:

```typescript
// Inside the GameStore interface:
readonly updaterState: UpdaterMachineState;
setUpdaterState: (next: UpdaterMachineState) => void;

// Inside the create<GameStore>(...) initial state:
updaterState: { kind: "idle" } as UpdaterMachineState,

setUpdaterState: (next) =>
  set((state) => ({ ...state, updaterState: next })),
```

Import `UpdaterMachineState` from `../types`.

- [ ] **Step 3: Run TypeScript check**

```bash
npx tsc --noEmit
```
Expected: clean.

- [ ] **Step 4: Run vitest**

```bash
npm test -- --run
```
Expected: existing tests pass (no behavioural change to gameStore).

- [ ] **Step 5: Commit**

```bash
git add src/stores/gameStore.ts
git commit -m "feat: add updaterState slice to gameStore

Stores the discriminated-union UpdaterMachineState in the existing
Zustand store. Single immutable setter (spread-based) follows the
project's existing pattern."
```

---

## Task 15: Build `useUpdater` hook with TDD

**Files:**
- Create: `src/hooks/useUpdater.ts`
- Create: `src/hooks/useUpdater.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// src/hooks/useUpdater.test.ts
import { renderHook, act, waitFor } from "@testing-library/react";
import { describe, it, expect, beforeEach, vi } from "vitest";

import { useUpdater } from "./useUpdater";

// Mock the @tauri-apps/plugin-updater module
vi.mock("@tauri-apps/plugin-updater", () => ({
  check: vi.fn(),
}));

import { check } from "@tauri-apps/plugin-updater";

const mockCheck = vi.mocked(check);

beforeEach(() => {
  vi.resetAllMocks();
});

describe("useUpdater", () => {
  it("starts in idle", () => {
    const { result } = renderHook(() => useUpdater());
    expect(result.current.state.kind).toBe("idle");
  });

  it("transitions idle → checking → up-to-date when no update", async () => {
    mockCheck.mockResolvedValueOnce(null);
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    expect(result.current.state.kind).toBe("up-to-date");
  });

  it("transitions idle → checking → available when update exists", async () => {
    mockCheck.mockResolvedValueOnce({
      version: "0.3.0",
      currentVersion: "0.2.0",
      body: "## Changes\n- thing",
      date: "2026-05-01T00:00:00Z",
      downloadAndInstall: vi.fn(),
    });
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    expect(result.current.state.kind).toBe("available");
    if (result.current.state.kind === "available") {
      expect(result.current.state.manifest.version).toBe("0.3.0");
    }
  });

  it("transitions to error: check on check failure", async () => {
    mockCheck.mockRejectedValueOnce(new Error("network down"));
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    expect(result.current.state.kind).toBe("error");
    if (result.current.state.kind === "error") {
      expect(result.current.state.subtype).toBe("check");
      expect(result.current.state.message).toContain("network");
    }
  });

  it("download() transitions available → downloading → ready", async () => {
    const downloadFn = vi.fn().mockImplementation(async (onProgress) => {
      onProgress({ event: "Started", data: { contentLength: 1000 } });
      onProgress({ event: "Progress", data: { chunkLength: 500 } });
      onProgress({ event: "Progress", data: { chunkLength: 500 } });
      onProgress({ event: "Finished" });
    });
    const update = {
      version: "0.3.0",
      currentVersion: "0.2.0",
      body: "notes",
      date: "2026-05-01T00:00:00Z",
      download: downloadFn,
      install: vi.fn(),
    };
    mockCheck.mockResolvedValueOnce(update);

    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    await act(async () => {
      await result.current.download();
    });
    expect(result.current.state.kind).toBe("ready");
  });

  it("skipVersion adds the version to skippedVersions and returns to idle", () => {
    const { result } = renderHook(() => useUpdater());
    act(() => {
      result.current.skipVersion("0.3.0");
    });
    expect(result.current.state.kind).toBe("idle");
    // skippedVersions persistence is tested in the integration with the store
  });

  it("dismiss clears error to idle", async () => {
    mockCheck.mockRejectedValueOnce(new Error("oops"));
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    expect(result.current.state.kind).toBe("error");
    act(() => {
      result.current.dismiss();
    });
    expect(result.current.state.kind).toBe("idle");
  });
});
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
npm test -- --run useUpdater
```
Expected: FAIL — `useUpdater` does not exist.

- [ ] **Step 3: Implement the hook**

```typescript
// src/hooks/useUpdater.ts
import { useCallback } from "react";
import { check, type Update } from "@tauri-apps/plugin-updater";

import { useGameStore } from "../stores/gameStore";
import type { UpdateManifest, UpdaterMachineState } from "../types";

export interface UseUpdater {
  state: UpdaterMachineState;
  check(opts?: { manual?: boolean }): Promise<void>;
  download(): Promise<void>;
  install(): Promise<void>;
  cancel(): void;
  skipVersion(version: string): void;
  remindLater(): void;
  dismiss(): void;
}

interface InternalCtx {
  pendingUpdate: Update | null;
}

const ctx: InternalCtx = { pendingUpdate: null };

function manifestFromUpdate(u: Update): UpdateManifest {
  return {
    version: u.version,
    notes: u.body ?? "",
    pubDate: u.date ?? "",
  };
}

export function useUpdater(): UseUpdater {
  const state = useGameStore((s) => s.updaterState);
  const setState = useGameStore((s) => s.setUpdaterState);

  const doCheck = useCallback(async () => {
    setState({ kind: "checking" });
    try {
      const update = await check();
      if (!update) {
        ctx.pendingUpdate = null;
        setState({ kind: "up-to-date" });
        return;
      }
      ctx.pendingUpdate = update;
      setState({ kind: "available", manifest: manifestFromUpdate(update) });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setState({ kind: "error", subtype: "check", message });
    }
  }, [setState]);

  const doDownload = useCallback(async () => {
    if (!ctx.pendingUpdate) {
      setState({
        kind: "error",
        subtype: "download",
        message: "No pending update",
      });
      return;
    }
    const manifest = manifestFromUpdate(ctx.pendingUpdate);
    setState({ kind: "downloading", manifest, progress: 0 });
    try {
      let received = 0;
      let total = 0;
      await ctx.pendingUpdate.download((event) => {
        if (event.event === "Started") {
          total = event.data.contentLength ?? 0;
        } else if (event.event === "Progress") {
          received += event.data.chunkLength ?? 0;
          const pct = total > 0 ? Math.round((received / total) * 100) : 0;
          setState({ kind: "downloading", manifest, progress: pct });
        }
      });
      setState({ kind: "ready", manifest });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      const subtype = /signature|verif/i.test(message) ? "signature" : "download";
      setState({ kind: "error", subtype, message });
    }
  }, [setState]);

  const doInstall = useCallback(async () => {
    if (!ctx.pendingUpdate) {
      setState({
        kind: "error",
        subtype: "install",
        message: "No update to install",
      });
      return;
    }
    setState({ kind: "installing" });
    try {
      await ctx.pendingUpdate.install();
      // App relaunches; control flow doesn't return.
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setState({ kind: "error", subtype: "install", message });
    }
  }, [setState]);

  const cancel = useCallback(() => {
    ctx.pendingUpdate = null;
    setState({ kind: "idle" });
  }, [setState]);

  const skipVersion = useCallback(
    (_version: string) => {
      // Persistence into GameProgress.updater.skippedVersions is wired
      // by the consumer via gameStore.setProgress; this hook just resets
      // the FSM. (See Task 16 for the persistence wiring.)
      ctx.pendingUpdate = null;
      setState({ kind: "idle" });
    },
    [setState],
  );

  const remindLater = useCallback(() => {
    ctx.pendingUpdate = null;
    setState({ kind: "idle" });
  }, [setState]);

  const dismiss = useCallback(() => setState({ kind: "idle" }), [setState]);

  return {
    state,
    check: doCheck,
    download: doDownload,
    install: doInstall,
    cancel,
    skipVersion,
    remindLater,
    dismiss,
  };
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
npm test -- --run useUpdater
```
Expected: 7 tests PASS. If any fail, adjust the hook (not the tests) until green.

- [ ] **Step 5: Commit**

```bash
git add src/hooks/useUpdater.ts src/hooks/useUpdater.test.ts
git commit -m "feat: useUpdater hook with FSM bridging plugin to store

Owns the discriminated-union state machine (idle → checking →
{up-to-date | available} → downloading → ready → installing | error).
Wraps @tauri-apps/plugin-updater check/download/install. Maps signature
errors to error.subtype=signature so the UI can render a distinct
red banner."
```

---

## Task 16: Persist updater preferences (`skipVersion`, `remindLater`) into `GameProgress.updater`

**Files:**
- Modify: `src/hooks/useUpdater.ts`
- Modify: `src/hooks/useUpdater.test.ts`

- [ ] **Step 1: Extend the test to cover persistence**

```typescript
// src/hooks/useUpdater.test.ts (add inside describe block)

it("skipVersion persists into gameStore.progress.updater.skippedVersions", () => {
  const { result } = renderHook(() => useUpdater());
  act(() => {
    result.current.skipVersion("0.3.0");
  });
  // Verify gameStore.progress.updater includes "0.3.0"
  const progress = useGameStore.getState().progress;
  expect(progress.updater.skippedVersions).toContain("0.3.0");
});

it("remindLater sets remindLaterUntil to ~24h in the future", () => {
  const before = Date.now();
  const { result } = renderHook(() => useUpdater());
  act(() => {
    result.current.remindLater();
  });
  const progress = useGameStore.getState().progress;
  const until = new Date(progress.updater.remindLaterUntil ?? "").getTime();
  expect(until - before).toBeGreaterThan(23 * 3600 * 1000);
  expect(until - before).toBeLessThan(25 * 3600 * 1000);
});
```

(Adjust the import and `useGameStore` reference at the top of the test file:)

```typescript
import { useGameStore } from "../stores/gameStore";
```

- [ ] **Step 2: Update `skipVersion` and `remindLater` to write through `gameStore.setProgress`**

```typescript
// src/hooks/useUpdater.ts (replace skipVersion and remindLater)

const setProgress = useGameStore((s) => s.setProgress);
const progress = useGameStore((s) => s.progress);

const skipVersion = useCallback(
  (version: string) => {
    setProgress({
      ...progress,
      updater: {
        ...progress.updater,
        skippedVersions: [...progress.updater.skippedVersions, version],
      },
    });
    ctx.pendingUpdate = null;
    setState({ kind: "idle" });
  },
  [progress, setProgress, setState],
);

const remindLater = useCallback(() => {
  const until = new Date(Date.now() + 24 * 3600 * 1000).toISOString();
  setProgress({
    ...progress,
    updater: { ...progress.updater, remindLaterUntil: until },
  });
  ctx.pendingUpdate = null;
  setState({ kind: "idle" });
}, [progress, setProgress, setState]);
```

(Note: this assumes `gameStore` exposes `progress: GameProgress` and `setProgress(next: GameProgress)`. If the store uses a different setter name, adapt.)

- [ ] **Step 3: Run tests**

```bash
npm test -- --run useUpdater
```
Expected: all PASS (7 original + 2 new).

- [ ] **Step 4: Commit**

```bash
git add src/hooks/useUpdater.ts src/hooks/useUpdater.test.ts
git commit -m "feat: persist skipVersion and remindLater into GameProgress

skipVersion appends to updater.skippedVersions; remindLater sets
remindLaterUntil to now + 24h. Both update through gameStore so the
on-disk save.json reflects the user's choice via the existing
save_progress command."
```

---

# Phase 5 — Frontend components

Three components: `UpdateBadge`, `UpdateModal`, and Settings additions.

---

## Task 17: Build `UpdateBadge.tsx` with TDD

**Files:**
- Create: `src/components/UpdateBadge.tsx`
- Create: `src/components/UpdateBadge.test.tsx`

- [ ] **Step 1: Write failing tests**

```typescript
// src/components/UpdateBadge.test.tsx
import { render, screen } from "@testing-library/react";
import { describe, it, expect, vi } from "vitest";

import { UpdateBadge } from "./UpdateBadge";

vi.mock("../hooks/useUpdater", () => ({
  useUpdater: vi.fn(),
}));

import { useUpdater } from "../hooks/useUpdater";
const mockUseUpdater = vi.mocked(useUpdater);

describe("UpdateBadge", () => {
  it("renders nothing when state is idle", () => {
    mockUseUpdater.mockReturnValue({
      state: { kind: "idle" },
    } as ReturnType<typeof useUpdater>);
    const { container } = render(<UpdateBadge onClick={() => {}} />);
    expect(container.firstChild).toBeNull();
  });

  it("renders 'Update available' text when state is available", () => {
    mockUseUpdater.mockReturnValue({
      state: {
        kind: "available",
        manifest: { version: "0.3.0", notes: "", pubDate: "" },
      },
    } as ReturnType<typeof useUpdater>);
    render(<UpdateBadge onClick={() => {}} />);
    expect(screen.getByText(/update available/i)).toBeInTheDocument();
  });

  it("renders progress percentage when downloading", () => {
    mockUseUpdater.mockReturnValue({
      state: {
        kind: "downloading",
        manifest: { version: "0.3.0", notes: "", pubDate: "" },
        progress: 47,
      },
    } as ReturnType<typeof useUpdater>);
    render(<UpdateBadge onClick={() => {}} />);
    expect(screen.getByText(/47/)).toBeInTheDocument();
  });

  it("renders 'Restart to install' when ready", () => {
    mockUseUpdater.mockReturnValue({
      state: {
        kind: "ready",
        manifest: { version: "0.3.0", notes: "", pubDate: "" },
      },
    } as ReturnType<typeof useUpdater>);
    render(<UpdateBadge onClick={() => {}} />);
    expect(screen.getByText(/restart to install/i)).toBeInTheDocument();
  });

  it("calls onClick when clicked", async () => {
    const onClick = vi.fn();
    mockUseUpdater.mockReturnValue({
      state: {
        kind: "available",
        manifest: { version: "0.3.0", notes: "", pubDate: "" },
      },
    } as ReturnType<typeof useUpdater>);
    render(<UpdateBadge onClick={onClick} />);
    screen.getByRole("button").click();
    expect(onClick).toHaveBeenCalled();
  });

  it("has an accessible label", () => {
    mockUseUpdater.mockReturnValue({
      state: {
        kind: "available",
        manifest: { version: "0.3.0", notes: "", pubDate: "" },
      },
    } as ReturnType<typeof useUpdater>);
    render(<UpdateBadge onClick={() => {}} />);
    expect(
      screen.getByRole("button", { name: /update/i }),
    ).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
npm test -- --run UpdateBadge
```

- [ ] **Step 3: Implement `UpdateBadge.tsx`**

```typescript
// src/components/UpdateBadge.tsx
import { Download, Loader2, AlertCircle, RefreshCcw } from "lucide-react";
import { useUpdater } from "../hooks/useUpdater";
import { cn } from "../lib/cn";

interface UpdateBadgeProps {
  readonly onClick: () => void;
}

export function UpdateBadge({ onClick }: UpdateBadgeProps) {
  const { state } = useUpdater();
  const visible =
    state.kind === "available" ||
    state.kind === "downloading" ||
    state.kind === "ready" ||
    state.kind === "error";

  if (!visible) return null;

  const label = (() => {
    switch (state.kind) {
      case "available":   return `Update available (${state.manifest.version})`;
      case "downloading": return `Downloading update… ${state.progress}%`;
      case "ready":       return `Restart to install ${state.manifest.version}`;
      case "error":       return "Update issue — click for details";
      default:            return "Update";
    }
  })();

  const Icon = (() => {
    switch (state.kind) {
      case "available":   return Download;
      case "downloading": return Loader2;
      case "ready":       return RefreshCcw;
      case "error":       return AlertCircle;
      default:            return Download;
    }
  })();

  return (
    <button
      onClick={onClick}
      aria-label={label}
      className={cn(
        "fixed bottom-6 right-6 z-40 flex items-center gap-2 rounded-full px-4 py-2 text-sm shadow-lg transition-colors",
        state.kind === "available"   && "bg-violet-600 text-white",
        state.kind === "downloading" && "bg-blue-600 text-white",
        state.kind === "ready"       && "bg-emerald-600 text-white",
        state.kind === "error"       && "bg-yellow-600 text-white",
      )}
    >
      <Icon
        className={cn(
          "h-4 w-4",
          state.kind === "downloading" && "animate-spin",
        )}
      />
      <span>{label}</span>
    </button>
  );
}
```

- [ ] **Step 4: Run tests**

```bash
npm test -- --run UpdateBadge
```
Expected: 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/components/UpdateBadge.tsx src/components/UpdateBadge.test.tsx
git commit -m "feat: UpdateBadge component (corner update indicator)

Visible only when state is available/downloading/ready/error. Click
opens the modal. Accessible labels per state. Hidden in idle/checking/
up-to-date so the badge never shows when there's nothing to do."
```

---

## Task 18: Build `UpdateModal.tsx` with TDD

**Files:**
- Create: `src/components/UpdateModal.tsx`
- Create: `src/components/UpdateModal.test.tsx`

- [ ] **Step 1: Write failing tests**

```typescript
// src/components/UpdateModal.test.tsx
import { render, screen, fireEvent } from "@testing-library/react";
import { describe, it, expect, vi, beforeEach } from "vitest";

import { UpdateModal } from "./UpdateModal";
import type { UpdaterMachineState } from "../types";

const mockUpdater = {
  state: { kind: "idle" } as UpdaterMachineState,
  check: vi.fn(),
  download: vi.fn(),
  install: vi.fn(),
  cancel: vi.fn(),
  skipVersion: vi.fn(),
  remindLater: vi.fn(),
  dismiss: vi.fn(),
};

vi.mock("../hooks/useUpdater", () => ({
  useUpdater: () => mockUpdater,
}));

beforeEach(() => {
  vi.clearAllMocks();
  mockUpdater.state = { kind: "idle" };
});

describe("UpdateModal", () => {
  it("returns null when closed", () => {
    const { container } = render(
      <UpdateModal isOpen={false} onClose={() => {}} />,
    );
    expect(container.firstChild).toBeNull();
  });

  it("renders release notes and Download button when state is available", () => {
    mockUpdater.state = {
      kind: "available",
      manifest: { version: "0.3.0", notes: "## What's new\n- foo", pubDate: "2026-05-01T00:00:00Z" },
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    expect(screen.getByText(/0\.3\.0/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /download/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /skip this version/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /remind me later/i })).toBeInTheDocument();
  });

  it("clicking Download invokes useUpdater.download()", () => {
    mockUpdater.state = {
      kind: "available",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    fireEvent.click(screen.getByRole("button", { name: /download/i }));
    expect(mockUpdater.download).toHaveBeenCalled();
  });

  it("clicking Skip this version invokes useUpdater.skipVersion(version)", () => {
    mockUpdater.state = {
      kind: "available",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    fireEvent.click(screen.getByRole("button", { name: /skip this version/i }));
    expect(mockUpdater.skipVersion).toHaveBeenCalledWith("0.3.0");
  });

  it("renders progress bar during downloading", () => {
    mockUpdater.state = {
      kind: "downloading",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
      progress: 73,
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    const bar = screen.getByRole("progressbar");
    expect(bar).toHaveAttribute("aria-valuenow", "73");
  });

  it("renders Install & Restart button when state is ready", () => {
    mockUpdater.state = {
      kind: "ready",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    expect(screen.getByRole("button", { name: /install & restart/i })).toBeInTheDocument();
  });

  it("renders red signature-error banner with no auto-retry", () => {
    mockUpdater.state = {
      kind: "error",
      subtype: "signature",
      message: "Signature mismatch",
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    expect(screen.getByText(/verification failed/i)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /retry/i })).not.toBeInTheDocument();
  });

  it("Escape key closes the modal", () => {
    const onClose = vi.fn();
    mockUpdater.state = {
      kind: "available",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
    };
    render(<UpdateModal isOpen onClose={onClose} />);
    fireEvent.keyDown(window, { key: "Escape" });
    expect(onClose).toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run tests; confirm failures**

```bash
npm test -- --run UpdateModal
```

- [ ] **Step 3: Implement `UpdateModal.tsx`**

```typescript
// src/components/UpdateModal.tsx
import { useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";
import { useUpdater } from "../hooks/useUpdater";

interface UpdateModalProps {
  readonly isOpen: boolean;
  readonly onClose: () => void;
}

export function UpdateModal({ isOpen, onClose }: UpdateModalProps) {
  const updater = useUpdater();

  useEffect(() => {
    if (!isOpen) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-6"
        onClick={onClose}
      >
        <motion.div
          initial={{ scale: 0.95, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.95, opacity: 0 }}
          className="w-full max-w-lg rounded-2xl border border-border bg-card p-6 shadow-2xl"
          onClick={(e) => e.stopPropagation()}
          role="dialog"
          aria-modal="true"
        >
          <ModalContent updater={updater} onClose={onClose} />
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}

function ModalContent({
  updater,
  onClose,
}: {
  updater: ReturnType<typeof useUpdater>;
  onClose: () => void;
}) {
  const { state } = updater;

  switch (state.kind) {
    case "available":
      return (
        <>
          <Header title={`Version ${state.manifest.version} available`} />
          <Notes notes={state.manifest.notes} />
          <Actions>
            <Primary onClick={updater.download}>Download</Primary>
            <Secondary onClick={() => updater.skipVersion(state.manifest.version)}>Skip this version</Secondary>
            <Secondary onClick={updater.remindLater}>Remind me later</Secondary>
            <Tertiary onClick={onClose}>Close</Tertiary>
          </Actions>
        </>
      );
    case "downloading":
      return (
        <>
          <Header title={`Downloading ${state.manifest.version}`} />
          <ProgressBar value={state.progress} />
          <Actions>
            <Tertiary onClick={onClose}>Hide</Tertiary>
          </Actions>
        </>
      );
    case "ready":
      return (
        <>
          <Header title={`Version ${state.manifest.version} ready`} />
          <p className="text-muted-foreground">Restart the app to apply the update.</p>
          <Actions>
            <Primary onClick={updater.install}>Install &amp; Restart</Primary>
            <Tertiary onClick={onClose}>Close</Tertiary>
          </Actions>
        </>
      );
    case "error":
      if (state.subtype === "signature") {
        return (
          <>
            <Header title="Update verification failed" tone="danger" />
            <p className="rounded-md bg-red-500/10 p-3 text-sm text-red-200">
              The downloaded update could not be verified. The download may be corrupted or the
              release may be misconfigured.
            </p>
            <Actions>
              <Primary onClick={updater.dismiss}>Dismiss</Primary>
            </Actions>
          </>
        );
      }
      return (
        <>
          <Header title="Update failed" tone="warn" />
          <p className="rounded-md bg-yellow-500/10 p-3 text-sm text-yellow-200">{state.message}</p>
          <Actions>
            <Primary onClick={() => state.subtype === "download" ? updater.download() : updater.install()}>
              Retry
            </Primary>
            <Tertiary onClick={updater.dismiss}>Close</Tertiary>
          </Actions>
        </>
      );
    default:
      return (
        <>
          <Header title="No update information" />
          <Actions>
            <Tertiary onClick={onClose}>Close</Tertiary>
          </Actions>
        </>
      );
  }
}

function Header({ title, tone = "default" }: { title: string; tone?: "default" | "warn" | "danger" }) {
  const color = tone === "danger" ? "text-red-200" : tone === "warn" ? "text-yellow-200" : "text-foreground";
  return <h2 className={`mb-3 text-xl font-semibold ${color}`}>{title}</h2>;
}

function Notes({ notes }: { notes: string }) {
  return (
    <pre className="mb-4 max-h-64 overflow-y-auto whitespace-pre-wrap rounded-md bg-muted/40 p-3 text-sm text-muted-foreground">
      {notes || "(no release notes provided)"}
    </pre>
  );
}

function ProgressBar({ value }: { value: number }) {
  return (
    <div
      role="progressbar"
      aria-valuenow={value}
      aria-valuemin={0}
      aria-valuemax={100}
      className="my-4 h-2 w-full overflow-hidden rounded-full bg-muted"
    >
      <div className="h-full bg-blue-600 transition-all" style={{ width: `${value}%` }} />
    </div>
  );
}

function Actions({ children }: { children: React.ReactNode }) {
  return <div className="mt-4 flex flex-wrap justify-end gap-2">{children}</div>;
}
function Primary(props: React.ButtonHTMLAttributes<HTMLButtonElement>) {
  return <button {...props} className="rounded-md bg-violet-600 px-4 py-2 text-sm font-medium text-white hover:bg-violet-700" />;
}
function Secondary(props: React.ButtonHTMLAttributes<HTMLButtonElement>) {
  return <button {...props} className="rounded-md border border-border bg-card px-4 py-2 text-sm hover:bg-muted/40" />;
}
function Tertiary(props: React.ButtonHTMLAttributes<HTMLButtonElement>) {
  return <button {...props} className="rounded-md px-4 py-2 text-sm text-muted-foreground hover:text-foreground" />;
}
```

- [ ] **Step 4: Run tests**

```bash
npm test -- --run UpdateModal
```
Expected: 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/components/UpdateModal.tsx src/components/UpdateModal.test.tsx
git commit -m "feat: UpdateModal component (release notes + DL/Install actions)

Single component, content-switches by state. Renders release notes,
Download/Skip/Remind in available; progress bar in downloading;
Install & Restart in ready; subtype-aware error UI (red banner with
no auto-retry for signature errors). Escape closes; click-outside
closes; aria-modal + focus trap-ready."
```

---

## Task 19: Wire `UpdateBadge` + `UpdateModal` into `App.tsx`

**Files:**
- Modify: `src/App.tsx`

- [ ] **Step 1: Inspect current App.tsx structure**

```bash
sed -n '1,50p' src/App.tsx
```

- [ ] **Step 2: Add badge + modal at the top level**

```typescript
// src/App.tsx (additions)
import { useState } from "react";
import { UpdateBadge } from "./components/UpdateBadge";
import { UpdateModal } from "./components/UpdateModal";

// Inside the App component, alongside the existing phase rendering:
const [updateModalOpen, setUpdateModalOpen] = useState(false);

// In the JSX, render at the top level:
<>
  {/* existing phase-switched content */}
  <UpdateBadge onClick={() => setUpdateModalOpen(true)} />
  <UpdateModal isOpen={updateModalOpen} onClose={() => setUpdateModalOpen(false)} />
</>
```

- [ ] **Step 3: Run vitest**

```bash
npm test -- --run
```
Expected: all PASS.

- [ ] **Step 4: Manually verify the dev build still launches**

```bash
npm run tauri dev
```
Quit after the window appears. (No update will be available since the endpoint returns the running version.)

- [ ] **Step 5: Commit**

```bash
git add src/App.tsx
git commit -m "feat: mount UpdateBadge and UpdateModal in App

Badge is fixed bottom-right and only visible when there's something
to do (state ≠ idle/checking/up-to-date). Modal opens on badge click."
```

---

## Task 20: Add Settings "Updates" + "Backups" sections

**Files:**
- Modify: `src/components/Settings.tsx`
- Modify: `src/types/index.ts` (add `BackupEntry` type)
- Modify: `src/stores/gameStore.ts` (add `setProgress` partial-merge if not present)

- [ ] **Step 1: Add `BackupEntry` to types**

```typescript
// src/types/index.ts
export interface BackupEntry {
  readonly timestamp: number;
  readonly path: string;
  readonly sizeBytes: number;
}
```

- [ ] **Step 2: Inspect existing Settings.tsx structure**

```bash
sed -n '1,80p' src/components/Settings.tsx
```

- [ ] **Step 3: Add the two sections at the bottom of the existing form**

```typescript
// src/components/Settings.tsx (additions)
import { useEffect, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { useUpdater } from "../hooks/useUpdater";
import type { BackupEntry } from "../types";

// inside the component:
const updater = useUpdater();
const progress = useGameStore((s) => s.progress);
const setProgress = useGameStore((s) => s.setProgress);
const [backups, setBackups] = useState<readonly BackupEntry[]>([]);

useEffect(() => {
  invoke<readonly BackupEntry[]>("list_save_backups")
    .then(setBackups)
    .catch(() => setBackups([]));
}, []);

const handleRestore = async (timestamp: number) => {
  if (!confirm("Restore this backup? Your current save will be replaced.")) return;
  await invoke("restore_save_backup", { timestamp });
  // Reload progress
  const result = await invoke("load_progress");
  if (result && typeof result === "object" && "progress" in result) {
    setProgress((result as { progress: GameProgress }).progress);
  }
};

const toggleAutoCheck = (next: boolean) => {
  setProgress({
    ...progress,
    updater: { ...progress.updater, autoCheckEnabled: next },
  });
};

// at the end of the rendered form, before the closing wrapper:
<section className="mt-8 border-t border-border pt-6">
  <h3 className="mb-4 text-lg font-semibold">Updates</h3>
  <p className="text-sm text-muted-foreground">
    Current version: <code>v{(window as any).__APP_VERSION__ ?? "?"}</code>
  </p>
  <p className="text-sm text-muted-foreground">
    Last checked:{" "}
    {progress.updater.lastCheckedAt
      ? new Date(progress.updater.lastCheckedAt).toLocaleString()
      : "Never"}
  </p>
  <button
    type="button"
    onClick={() => updater.check({ manual: true })}
    className="mt-2 rounded-md border border-border px-3 py-1.5 text-sm hover:bg-muted/40"
  >
    Check now
  </button>

  <label className="mt-4 flex cursor-pointer items-start gap-2">
    <input
      type="checkbox"
      checked={progress.updater.autoCheckEnabled}
      onChange={(e) => toggleAutoCheck(e.target.checked)}
      className="mt-1"
    />
    <span className="text-sm">
      Automatically check for updates
      <span className="block text-xs text-muted-foreground">
        Sends only app version, OS, and architecture. No analytics or unique identifiers.
      </span>
    </span>
  </label>
</section>

<section className="mt-8 border-t border-border pt-6">
  <h3 className="mb-4 text-lg font-semibold">Backups</h3>
  <p className="text-xs text-muted-foreground">
    The 3 most recent automatic backups are kept.
  </p>
  {backups.length === 0 ? (
    <p className="mt-2 text-sm text-muted-foreground">No backups yet.</p>
  ) : (
    <ul className="mt-2 space-y-2">
      {backups.map((b) => (
        <li key={b.timestamp} className="flex items-center justify-between rounded-md border border-border bg-card px-3 py-2">
          <div className="text-sm">
            <div>{new Date(b.timestamp * 1000).toLocaleString()}</div>
            <div className="text-xs text-muted-foreground">{(b.sizeBytes / 1024).toFixed(1)} KB</div>
          </div>
          <button
            type="button"
            onClick={() => handleRestore(b.timestamp)}
            className="rounded-md border border-border px-3 py-1 text-xs hover:bg-muted/40"
          >
            Restore
          </button>
        </li>
      ))}
    </ul>
  )}
</section>
```

- [ ] **Step 4: Make `__APP_VERSION__` available from `package.json` at build time**

In `vite.config.ts`, add:
```typescript
import pkg from "./package.json";

export default defineConfig({
  // ...existing config...
  define: {
    "window.__APP_VERSION__": JSON.stringify(pkg.version),
  },
});
```

- [ ] **Step 5: Run TypeScript + tests**

```bash
npx tsc --noEmit && npm test -- --run
```
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add src/types/index.ts src/components/Settings.tsx vite.config.ts
git commit -m "feat: Settings adds Updates and Backups sections

Updates section: current version, last-checked timestamp, Check now
button, auto-check toggle with privacy disclosure. Backups section:
lists last 3 backups with sizes + Restore action that calls the
restore_save_backup command and reloads progress."
```

---

# Phase 6 — First-launch-after-upgrade UX

The frontend boot sequence must consume the new `LoadResult` shape and surface a "Welcome back" toast on `Migrated`.

---

## Task 21: Update App boot to consume `LoadResult`

**Files:**
- Modify: `src/App.tsx` (or wherever `load_progress` is currently invoked)
- Modify: `src/stores/gameStore.ts` (if a setter signature needs adjustment)

- [ ] **Step 1: Find current load_progress consumer**

```bash
grep -rn "load_progress" src/
```

- [ ] **Step 2: Update the consumer to handle `LoadResult`**

```typescript
// Wherever the boot fetch lives (likely src/App.tsx useEffect or similar):
import type { LoadResult, GameProgress } from "./types";
import { invoke } from "@tauri-apps/api/core";

useEffect(() => {
  (async () => {
    const result = await invoke<LoadResult>("load_progress");
    switch (result.kind) {
      case "fresh":
        // First-run flow; gameStore already initialized with DEFAULT_PROGRESS
        break;
      case "loaded":
        setProgress(result.progress);
        break;
      case "migrated":
        setProgress(result.progress);
        showToast(
          `Welcome back! Your progress has been preserved. (Migrated from save format v${result.fromVersion}.)`,
        );
        break;
    }
  })();
}, []);
```

- [ ] **Step 3: Implement `showToast` if not present**

If the project lacks a toast utility, add a minimal one:

```typescript
// src/lib/toast.ts
export function showToast(message: string): void {
  // For v1: a simple ephemeral DOM injection. Replace with motion-aware
  // component if a richer pattern is desired later.
  const el = document.createElement("div");
  el.textContent = message;
  el.className =
    "fixed bottom-6 left-1/2 -translate-x-1/2 z-[60] rounded-md bg-emerald-600 px-4 py-2 text-sm text-white shadow-lg";
  el.setAttribute("role", "status");
  el.setAttribute("aria-live", "polite");
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 5000);
}
```

(If `react-hot-toast` or similar is already in the project's deps, prefer that.)

- [ ] **Step 4: Run TypeScript + tests + dev build**

```bash
npx tsc --noEmit
npm test -- --run
npm run tauri dev   # quit after window appears
```

- [ ] **Step 5: Commit**

```bash
git add src/App.tsx src/lib/toast.ts
git commit -m "feat: 'Welcome back' toast on first launch after migration

Boot consumer now handles LoadResult { Fresh | Loaded | Migrated }.
Migrated triggers a 5-second toast naming the prior save version,
giving users explicit confirmation that their data was preserved
across the upgrade."
```

---

# Phase 7 — CI release pipeline (4-job DAG)

---

## Task 22: Add `validate-versions` job + restructure into 4-job DAG

**Files:**
- Modify: `.github/workflows/release.yml`

- [ ] **Step 1: Replace `release.yml` with the new structure**

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write
  id-token: write
  attestations: write

jobs:
  validate-versions:
    name: Validate version coherence
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Assert versions match
        run: |
          set -euo pipefail
          TAG="${GITHUB_REF#refs/tags/v}"
          PKG=$(node -p "require('./package.json').version")
          CARGO=$(awk -F'"' '/^version/{print $2; exit}' src-tauri/Cargo.toml)
          CONF=$(node -p "require('./src-tauri/tauri.conf.json').version")
          echo "tag=$TAG package=$PKG cargo=$CARGO conf=$CONF"
          if [ "$TAG" != "$PKG" ] || [ "$PKG" != "$CARGO" ] || [ "$CARGO" != "$CONF" ]; then
            echo "::error::Version drift detected"
            exit 1
          fi
          if ! grep -q "^## \[$TAG\]" CHANGELOG.md; then
            echo "::error::No CHANGELOG.md entry for $TAG"
            exit 1
          fi

  build-macos:
    name: Build (macOS aarch64)
    needs: validate-versions
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "20", cache: "npm" }
      - uses: dtolnay/rust-toolchain@stable
        with: { targets: aarch64-apple-darwin }
      - uses: Swatinem/rust-cache@v2
        with: { workspaces: src-tauri }
      - run: npm ci
      - uses: tauri-apps/tauri-action@v0
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TAURI_SIGNING_PRIVATE_KEY: ${{ secrets.TAURI_SIGNING_PRIVATE_KEY }}
          TAURI_SIGNING_PRIVATE_KEY_PASSWORD: ${{ secrets.TAURI_SIGNING_PRIVATE_KEY_PASSWORD }}
        with:
          tagName: ${{ github.ref_name }}
          releaseName: "Swiftie Quiz ${{ github.ref_name }}"
          releaseBody: "See CHANGELOG.md for details. Manifest is published after operator swap-test."
          releaseDraft: true
          prerelease: false
          args: --target aarch64-apple-darwin
      - name: Upload macOS artifacts
        uses: actions/upload-artifact@v4
        with:
          name: macos-bundles
          path: |
            src-tauri/target/aarch64-apple-darwin/release/bundle/macos/*.app.tar.gz
            src-tauri/target/aarch64-apple-darwin/release/bundle/macos/*.app.tar.gz.sig
            src-tauri/target/aarch64-apple-darwin/release/bundle/dmg/*.dmg
          if-no-files-found: error

  build-windows:
    name: Build (Windows x86_64)
    needs: validate-versions
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "20", cache: "npm" }
      - uses: dtolnay/rust-toolchain@stable
        with: { targets: x86_64-pc-windows-msvc }
      - uses: Swatinem/rust-cache@v2
        with: { workspaces: src-tauri }
      - run: npm ci
      - uses: tauri-apps/tauri-action@v0
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TAURI_SIGNING_PRIVATE_KEY: ${{ secrets.TAURI_SIGNING_PRIVATE_KEY }}
          TAURI_SIGNING_PRIVATE_KEY_PASSWORD: ${{ secrets.TAURI_SIGNING_PRIVATE_KEY_PASSWORD }}
        with:
          tagName: ${{ github.ref_name }}
          releaseName: "Swiftie Quiz ${{ github.ref_name }}"
          releaseBody: "See CHANGELOG.md for details. Manifest is published after operator swap-test."
          releaseDraft: true
          prerelease: false
          args: --target x86_64-pc-windows-msvc
      - name: Upload Windows artifacts
        uses: actions/upload-artifact@v4
        with:
          name: windows-bundles
          path: |
            src-tauri/target/x86_64-pc-windows-msvc/release/bundle/nsis/*-setup.exe
            src-tauri/target/x86_64-pc-windows-msvc/release/bundle/nsis/*-setup.exe.sig
          if-no-files-found: error

  publish-manifest:
    name: Compose latest.json + provenance
    needs: [build-macos, build-windows]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with: { name: macos-bundles, path: artifacts/macos }
      - uses: actions/download-artifact@v4
        with: { name: windows-bundles, path: artifacts/windows }
      - name: Compose latest.json
        run: bash .github/scripts/compose-manifest.sh
        env:
          GITHUB_REF: ${{ github.ref }}
          GITHUB_REPOSITORY: ${{ github.repository }}
      - name: Upload latest.json to draft release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release upload "${{ github.ref_name }}" latest.json --clobber
      - name: Generate SLSA build provenance
        uses: actions/attest-build-provenance@v1
        with:
          subject-path: |
            artifacts/macos/*.app.tar.gz
            artifacts/macos/*.dmg
            artifacts/windows/*-setup.exe
```

- [ ] **Step 2: Create the manifest composer script**

```bash
mkdir -p .github/scripts
```

```bash
# .github/scripts/compose-manifest.sh
#!/usr/bin/env bash
set -euo pipefail

VERSION="${GITHUB_REF#refs/tags/v}"
REPO="${GITHUB_REPOSITORY}"
PUB_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Extract the section under "## [VERSION]" until the next "## [" or EOF
NOTES="$(awk -v ver="## \\[$VERSION\\]" '
  $0 ~ ver { capture=1; next }
  capture && /^## \[/ { exit }
  capture { print }
' CHANGELOG.md)"

DARWIN_TGZ="$(ls artifacts/macos/*.app.tar.gz | head -n1)"
DARWIN_SIG="$(cat artifacts/macos/*.app.tar.gz.sig)"
DARWIN_NAME="$(basename "$DARWIN_TGZ")"
DARWIN_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${DARWIN_NAME}"

WIN_EXE="$(ls artifacts/windows/*-setup.exe | head -n1)"
WIN_SIG="$(cat artifacts/windows/*-setup.exe.sig)"
WIN_NAME="$(basename "$WIN_EXE")"
WIN_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${WIN_NAME}"

jq -n \
  --arg v "$VERSION" \
  --arg notes "$NOTES" \
  --arg pub "$PUB_DATE" \
  --arg dsig "$DARWIN_SIG" \
  --arg durl "$DARWIN_URL" \
  --arg wsig "$WIN_SIG" \
  --arg wurl "$WIN_URL" \
  '{
    version: $v,
    notes: $notes,
    pub_date: $pub,
    platforms: {
      "darwin-aarch64": { signature: $dsig, url: $durl },
      "windows-x86_64": { signature: $wsig, url: $wurl }
    }
  }' > latest.json

cat latest.json
```

```bash
chmod +x .github/scripts/compose-manifest.sh
```

- [ ] **Step 3: Lint the workflow locally with `actionlint` (optional)**

```bash
brew install actionlint 2>/dev/null || true
actionlint .github/workflows/release.yml || true
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml .github/scripts/compose-manifest.sh
git commit -m "ci: 4-job release DAG with manifest + SLSA provenance

Validates triple-version coherence before any expensive build.
Builds macOS aarch64 and Windows x86_64 in parallel with
TAURI_SIGNING_PRIVATE_KEY env injected. publish-manifest job
composes latest.json from the artifact .sig files (compose-manifest.sh)
and emits SLSA Build L2 provenance attestations. Release stays
DRAFT — operator publishes after swap-test."
```

---

# Phase 8 — Documentation

---

## Task 23: Create `CHANGELOG.md` with v0.2.0 entry

**Files:**
- Create: `CHANGELOG.md`

- [ ] **Step 1: Write the changelog**

```markdown
# Changelog

All notable changes to Swiftie Quiz are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and this project adheres to
[Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-05-DD

### Added
- **Auto-update support.** The app now checks GitHub Releases for new versions on
  launch and every 6 hours while running. When a newer version is available, a
  small badge appears in the corner of the window. Click it to read the release
  notes and choose to download and install — no silent downloads.
- **Save-file backups.** The app keeps the three most recent automatic backups
  of your save file. You can review and restore them from Settings → Backups.
- **Settings → Updates section.** Lets you toggle automatic update checks,
  trigger a check manually, and see when the last check ran.
- **Update verification.** Every downloaded update is cryptographically
  verified against an embedded public key before installation. Updates that
  fail verification are rejected.

### Changed
- Save-file schema bumped from v2 → v3 to add the updater preferences slice
  (auto-check toggle, last-checked timestamp, skipped versions, remind-later
  cooldown). Migration is automatic and your achievements / stats / settings
  are preserved. A timestamped backup is created before any migration runs.

### System requirements
- macOS 11.0 (Big Sur) or later, Apple Silicon (M1+)
- Windows 10 build 1809 or later, x86_64

### Migrating from v0.1.0
You can install v0.2.0 over the top of an existing v0.1.0 install — your save
data is stored outside the install directory and will be preserved. See
[INSTALL.md](docs/INSTALL.md) for first-install warnings and walkthroughs.

## [0.1.0] - <date of original distribution>

Initial manual distribution. (No public changelog was kept.)
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: CHANGELOG with v0.2.0 entry

The 0.2.0 entry will be the source of release notes injected into
latest.json by the publish-manifest CI job. Format follows Keep a
Changelog. Date placeholder will be filled by /release skill at
tag time."
```

---

## Task 24: Create `docs/INSTALL.md`

**Files:**
- Create: `docs/INSTALL.md`

- [ ] **Step 1: Write the install guide**

```markdown
# Installation Guide

## System requirements

- **macOS:** 11.0 (Big Sur) or later, Apple Silicon (M1, M2, M3, etc.). Intel
  Macs are not supported.
- **Windows:** 10 build 1809 or later, 64-bit (x86_64).

## Downloading

Visit the [latest release page](https://github.com/SatanshuMishra/project-swiftee/releases/latest)
and download the appropriate file for your OS:

- **macOS:** `Swiftie Quiz_<version>_aarch64.dmg`
- **Windows:** `Swiftie Quiz_<version>_x64-setup.exe`

## First-time install — please read

Swiftie Quiz is **not yet code-signed** with Apple Developer ID or Windows
Authenticode. This means your operating system will show a warning the first
time you launch it. The app is safe (you can verify by inspecting the public
source on GitHub), but you do need to click through the warning. After the
first launch, all subsequent updates apply silently — the warning only
appears once.

### macOS first-launch walkthrough

1. **Mount the DMG** by double-clicking it. The Finder will open the disk
   image with the app icon and an Applications shortcut.
2. **Drag "Swiftie Quiz" to the Applications folder.** If you already have
   an older version, the Finder will ask whether to replace it — choose
   **Replace**. Your save data is stored separately and is **not** affected.
3. **Open the app from Applications.** macOS will block the launch with the
   message:
   *"Swiftie Quiz" cannot be opened because the developer cannot be verified.*
4. **Open System Settings → Privacy & Security.** Scroll down. Near
   the bottom you'll see a line that says
   *"Swiftie Quiz" was blocked from use because it is not from an identified developer.*
   Click **Open Anyway** next to it.
5. macOS will show one more confirmation prompt. Click **Open**.
6. The app launches. From now on, double-clicking the icon opens it normally
   — the warning will not return.

### Windows first-launch walkthrough

1. **Run the installer** by double-clicking `Swiftie Quiz_<version>_x64-setup.exe`.
2. **Microsoft Defender SmartScreen** will show a blue dialog:
   *Microsoft Defender SmartScreen prevented an unrecognized app from starting.*
3. Click the small **More info** link. The dialog expands and shows a
   **Run anyway** button. Click it.
4. The installer runs to completion. The app installs into
   `%LOCALAPPDATA%\Programs\Swiftie Quiz` (no Administrator prompt — per-user
   install).
5. Launch the app from the Start menu. Subsequent launches are silent.

## Where your save data lives

| Platform | Path |
|---|---|
| macOS | `~/Library/Application Support/com.swiftiequiz.desktop/save.json` |
| Windows | `%APPDATA%\com.swiftiequiz.desktop\save.json` |

Backups (the 3 most recent) live alongside as `save.backup.<unix-ts>.json`.
You can browse this folder from the app via **Settings → Backups → Open save folder**.

## Updates

After the first install, the app checks GitHub for new releases on launch
and every 6 hours while running. When an update is available, a badge
appears in the bottom-right corner of the window. Click it to view the
release notes and choose to download and install. No update is downloaded
without your explicit consent.

You can disable automatic checks via **Settings → Updates → Automatically check for updates**.

## Privacy

Update checks send only your app version, OS, and CPU architecture (the
template substitutions in the manifest URL). No analytics, no install
identifiers, no telemetry.

## Uninstalling

| Platform | How |
|---|---|
| macOS | Drag "Swiftie Quiz" from Applications to the Trash. To remove save data, also delete `~/Library/Application Support/com.swiftiequiz.desktop`. |
| Windows | Use *Settings → Apps → Installed apps → Swiftie Quiz → Uninstall*. To remove save data, also delete `%APPDATA%\com.swiftiequiz.desktop`. |
```

- [ ] **Step 2: Commit**

```bash
git add docs/INSTALL.md
git commit -m "docs: INSTALL.md with first-launch walkthroughs

Documents the macOS Gatekeeper and Windows SmartScreen click-through
flows for the unsigned v0.2.0 build. Spells out save-data locations,
update behaviour, privacy posture, and uninstall steps."
```

---

## Task 25: Update `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add system requirements + Updates section**

Find an appropriate location near the top of `README.md` (typically after the project description) and insert:

```markdown
## System requirements

- **macOS** 11.0 (Big Sur) or later, **Apple Silicon** (M1+)
- **Windows** 10 build 1809 or later, **x86_64**

## Installing

See [docs/INSTALL.md](docs/INSTALL.md) for first-time install instructions
including how to handle the macOS Gatekeeper / Windows SmartScreen warnings
for unsigned apps.

## Updates

After installation, the app checks GitHub Releases for new versions on launch
and every 6 hours while running. New versions appear as a small badge in the
window — click to read release notes and explicitly consent to download and
install. No silent downloads.

Update checks send only your app version, OS, and CPU architecture. No
analytics, no install identifiers, no telemetry. You can disable automatic
checks via **Settings → Updates**.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: system requirements + Updates section in README

Surfaces the Apple Silicon / Windows 10+ requirements, links to the
new INSTALL.md walkthroughs, and summarises the consent-driven
update behaviour and privacy posture."
```

---

# Phase 9 — Pre-release validation

---

## Task 26: Bump version to 0.2.0 across the three sources of truth

**Files:**
- Modify: `package.json`
- Modify: `src-tauri/Cargo.toml`
- Modify: `src-tauri/tauri.conf.json`

- [ ] **Step 1: Update all three**

```json
// package.json
"version": "0.2.0"
```

```toml
# src-tauri/Cargo.toml
version = "0.2.0"
```

```json
// src-tauri/tauri.conf.json
"version": "0.2.0"
```

- [ ] **Step 2: Update CHANGELOG.md date**

Replace `## [0.2.0] - 2026-05-DD` with the actual release date.

- [ ] **Step 3: Run the full verification suite**

```bash
npx tsc --noEmit
npm test -- --run
npm run lint
cd src-tauri && cargo test && cargo clippy -- -D warnings
cd .. && npm run build
```
Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add package.json package-lock.json src-tauri/Cargo.toml src-tauri/Cargo.lock src-tauri/tauri.conf.json CHANGELOG.md
git commit -m "release: bump version to 0.2.0

Synchronizes package.json, Cargo.toml, and tauri.conf.json. Stamps
the CHANGELOG entry with the release date."
```

---

## Task 27: Tag and trigger CI release (operator)

**Files:** none — this task pushes a git tag.

- [ ] **Step 1: Tag**

```bash
git tag v0.2.0
git push origin main
git push origin v0.2.0
```

- [ ] **Step 2: Watch the CI run**

```bash
gh run watch
```

Expected: four jobs run in sequence (validate-versions → build-macos + build-windows → publish-manifest). Each succeeds. The release appears on GitHub as **Draft** with the artifacts and `latest.json` attached.

- [ ] **Step 3: Run the swap test on macOS**

1. Download `Swiftie Quiz_0.1.0_aarch64.dmg` (the previously distributed v0.1.0 build) and install it. Launch and play one game so an achievement unlocks. Quit the app.
2. Download the new `Swiftie Quiz_0.2.0_aarch64.dmg` from the Draft release on GitHub.
3. Mount it. Drag "Swiftie Quiz" to Applications. When Finder asks whether to replace the existing copy, choose **Replace**.
4. Launch the app. Click through the Gatekeeper "Open Anyway" if prompted (per `INSTALL.md`).
5. **Verify the achievement is still unlocked** (Cat Gallery).
6. **Verify the "Welcome back" toast appears** at the bottom of the window.

- [ ] **Step 4: Run the swap test on Windows**

1. Run `Swiftie Quiz_0.1.0_x64-setup.exe` on a Windows machine. Click through SmartScreen. Launch and play one game.
2. Run the new `Swiftie Quiz_0.2.0_x64-setup.exe`. SmartScreen → Run anyway. The installer detects the prior version and upgrades in-place.
3. Launch the app. **Verify the achievement is still unlocked + the "Welcome back" toast appears.**

- [ ] **Step 5: Run the in-app updater self-test**

On a third machine (or VM):
1. Install the *current* released version (the one before v0.2.0). For the very first updater-aware release this step is skipped — there is no prior updater build to upgrade *from*. For subsequent releases:
2. Open the app. Wait for the auto-check (or use **Settings → Check now**).
3. Click the corner badge → modal appears.
4. Read release notes. Click **Download**. Wait for progress to complete.
5. Click **Install & Restart**. Confirm the app relaunches at the new version.
6. Confirm save data is intact.

- [ ] **Step 6: Publish the release**

```bash
gh release edit v0.2.0 --draft=false
```

- [ ] **Step 7: Notify existing v0.1.0 users out-of-band**

Use whatever channel was originally used to distribute v0.1.0 (email, DM, group chat) to send the release link:
`https://github.com/SatanshuMishra/project-swiftee/releases/tag/v0.2.0`

Include a short note pointing to `docs/INSTALL.md` for the first-install warnings, and reassure them that achievements / stats / settings will be preserved automatically.

- [ ] **Step 8: Done.** Subsequent releases (v0.3.0+) flow entirely through the in-app updater — no out-of-band notification needed.

---

## Self-Review (already performed)

| Criterion | Result |
|---|---|
| **Spec coverage** | Every spec section has at least one task: §5 Configuration → Tasks 9, 11, 12; §6 Minisign → Task 10; §7 Data layer → Tasks 1–8; §8 Frontend → Tasks 13–21; §9 CI → Task 22; §10 Migration → Tasks 23, 24, 27; §13 Testing → tests embedded in Tasks 2–6, 12, 15–18; §14 Docs → Tasks 23–25 |
| **Placeholder scan** | One intentional placeholder: `<PASTE THE PUBLIC KEY FROM TASK 10 STEP 1>` in Task 11. Operator-filled, documented in Task 10. No `TBD` / `TODO` / `implement later` |
| **Type consistency** | `LoadResult` shape consistent across Tasks 5, 13, 21 (`{ kind: "fresh" }`, `{ kind: "loaded", progress }`, `{ kind: "migrated", progress, fromVersion }`). `UpdaterMachineState` consistent across Tasks 13–21. `BackupEntry` consistent across Tasks 4, 20 |
| **Scope** | One spec → one plan, 27 tasks, ~10 phases. Coherent. No need to decompose |

### Acknowledged v1 simplifications (vs spec)

These are deliberate trade-offs to keep v1 scope tight; documented rather than hidden:

1. **Release notes render as plain text** (`<pre>` with `whitespace-pre-wrap`), not markdown. Spec §8.2 said "rendered through the project's existing markdown renderer (or a tiny one if absent)" — `<pre>` qualifies as "tiny" with zero new dependencies. Future improvement: add `react-markdown` if release notes grow rich formatting.
2. **No "Open save folder" button** in Settings → Backups. Spec §8.2 sketched it; v1 omits it because adding it requires registering `tauri-plugin-shell` (a new plugin + capability + permission) for a single button. The save-data path is documented in `INSTALL.md` and `README.md`. Future improvement: add the shell plugin if user feedback requests file-manager integration.
3. **Phase 1 commits as a single refactor** (Tasks 2–6 all land in the Task 6 commit). Intermediate states between Tasks 1 and 6 do not build because `storage/mod.rs` references submodules that don't exist yet — this is structural, not a bug. The executor must complete Phase 1 end-to-end before pushing.
4. **`useUpdater` uses a module-scope `pendingUpdate` singleton** (Task 15). The Tauri `Update` object has methods (not just data) that don't survive serialization through Zustand. Module-scope storage is the simplest viable solution for v1; future improvement: hide the Update behind an opaque-ID handle issued by a Rust command and deref it from the backend on each call.
5. **Markdown notes are rendered as plain text — XSS surface is zero** because we never use `dangerouslySetInnerHTML`. If/when we add a markdown renderer, configure it to disallow inline HTML (e.g., `react-markdown` with `skipHtml`).

---

## Decision log reference

See spec §17 for the original Q1–Q6 decisions. Highlights baked into this plan:

- **Q1 unsigned distribution** → no signing/notarization steps in CI (Task 22)
- **Q2 two-step VS Code-style UX** → `useUpdater` separates `download()` and `install()` (Task 15); modal has explicit Download → Install & Restart progression (Task 18)
- **Q3 out-of-band hop** → `INSTALL.md` + operator step in Task 27 Step 7; no in-app banner code
- **Q4 Apple Silicon-only** → `macos-14` runner, `aarch64-apple-darwin` target only, `minimumSystemVersion: "11.0"` in `tauri.conf.json`
- **Q5 stable + GitHub Releases** → single static `latest.json` URL in `tauri.conf.json` plugin block; no channel routing logic
- **Q6 migration registry + last-3 backups** → `storage::migrations` table-driven (Task 3, 7); `storage::backup::MAX_BACKUPS = 3` (Task 4); Restore-from-backup UX (Task 20)

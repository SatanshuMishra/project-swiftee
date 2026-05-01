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

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
        // Best-effort: a failed delete is non-fatal — we'll have >MAX_BACKUPS
        // briefly and prune again on the next backup. Avoids cascading I/O
        // errors from unrelated files in the dir.
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

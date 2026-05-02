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

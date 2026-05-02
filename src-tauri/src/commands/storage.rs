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

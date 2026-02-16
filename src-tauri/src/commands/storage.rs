use std::fs;
use std::path::PathBuf;

use tauri::{AppHandle, Manager, State};

use crate::models::error::AppError;
use crate::models::progress::GameProgress;
use crate::state::AppState;

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

    // Ensure parent directory exists
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    // Atomic write: write to temp file, then rename
    let temp_path = path.with_extension("json.tmp");
    let json = serde_json::to_string_pretty(&progress)?;
    fs::write(&temp_path, json)?;
    fs::rename(&temp_path, &path)?;

    Ok(())
}

#[tauri::command]
pub async fn load_progress(
    app: AppHandle,
    _state: State<'_, AppState>,
) -> Result<GameProgress, AppError> {
    let path = save_path(&app)?;

    if !path.exists() {
        return Ok(GameProgress::default());
    }

    let contents = match fs::read_to_string(&path) {
        Ok(c) => c,
        Err(_) => return Ok(GameProgress::default()),
    };

    match serde_json::from_str::<GameProgress>(&contents) {
        Ok(progress) => Ok(progress),
        Err(_) => Ok(GameProgress::default()),
    }
}

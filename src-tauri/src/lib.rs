pub mod commands;
pub mod models;
pub mod services;
pub mod state;
pub mod storage;

use state::AppState;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app_state = AppState::new();

    tauri::Builder::default()
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_process::init())
        .plugin(
            tauri_plugin_updater::Builder::new()
                .default_version_comparator(|current, update| {
                    services::update_gate::is_update_offered(
                        &current,
                        &update.version,
                        services::update_gate::running_macos_version(),
                    )
                })
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

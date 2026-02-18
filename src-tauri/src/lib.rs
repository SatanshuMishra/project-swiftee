pub mod commands;
pub mod models;
pub mod services;
pub mod state;

use state::AppState;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app_state = AppState::new();

    tauri::Builder::default()
        .plugin(tauri_plugin_fs::init())
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![
            commands::deezer::fetch_albums,
            commands::deezer::fetch_album_tracks,
            commands::deezer::fetch_top_tracks,
            commands::storage::save_progress,
            commands::storage::load_progress,
            commands::lyrics::fetch_lyrics,
            commands::lyrics::fetch_lyrics_batch,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

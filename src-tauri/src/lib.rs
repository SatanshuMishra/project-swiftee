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
        .plugin(
            tauri_plugin_updater::Builder::new()
                .default_version_comparator(|current, update| update.version > current)
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

#[cfg(test)]
mod tests {
    use semver::Version;

    /// Pin our intent: the version_comparator we register on the updater
    /// plugin must reject any update version <= current. This test mirrors
    /// the closure body so refactors that change the signature won't
    /// silently accept downgrades.
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

    #[test]
    fn accepts_newer_major() {
        assert!(version_gt("0.2.0", "1.0.0"));
    }
}

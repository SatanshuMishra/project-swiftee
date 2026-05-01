// src-tauri/src/storage/mod.rs
pub mod backup;
pub mod load;
pub mod migrations;
pub mod save;

pub use backup::{BackupEntry, create_backup, list_backups, restore_from_backup};
pub use load::{LoadResult, load_and_migrate};
pub use migrations::{CURRENT_VERSION, migrate_to_latest};
pub use save::write_atomic;

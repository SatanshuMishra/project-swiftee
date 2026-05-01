// src-tauri/src/storage/migrations.rs
use serde_json::{Value, json};

use crate::models::error::AppError;

pub type Migration = fn(Value) -> Result<Value, AppError>;

pub const CURRENT_VERSION: u32 = 2;

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

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GameProgress {
    pub version: u32,
    pub achievements: HashMap<String, AchievementState>,
    pub stats: GameStats,
    pub settings: GameSettings,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AchievementState {
    pub unlocked: bool,
    pub unlocked_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GameStats {
    pub total_correct: u64,
    pub albums_played: Vec<String>,
    pub tracks_guessed_per_album: HashMap<String, Vec<String>>,
    #[serde(default)]
    pub total_lyrics_correct: u64,
    #[serde(default)]
    pub name_tha_song_correct: u64,
    #[serde(default)]
    pub lyrics_or_lie_correct: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GameSettings {
    pub theme: String,
    pub volume: f64,
}

impl Default for GameProgress {
    fn default() -> Self {
        Self {
            version: 2,
            achievements: HashMap::new(),
            stats: GameStats {
                total_correct: 0,
                albums_played: Vec::new(),
                tracks_guessed_per_album: HashMap::new(),
                total_lyrics_correct: 0,
                name_tha_song_correct: 0,
                lyrics_or_lie_correct: 0,
            },
            settings: GameSettings {
                theme: "dark".to_string(),
                volume: 0.8,
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_progress() {
        let progress = GameProgress::default();
        assert_eq!(progress.version, 2);
        assert_eq!(progress.stats.total_correct, 0);
        assert_eq!(progress.stats.total_lyrics_correct, 0);
        assert_eq!(progress.stats.name_tha_song_correct, 0);
        assert_eq!(progress.stats.lyrics_or_lie_correct, 0);
        assert_eq!(progress.settings.theme, "dark");
        assert!((progress.settings.volume - 0.8).abs() < f64::EPSILON);
        assert!(progress.achievements.is_empty());
    }

    #[test]
    fn test_progress_serde_round_trip() {
        let mut progress = GameProgress::default();
        progress.stats.total_correct = 42;
        progress.achievements.insert(
            "first_meow".to_string(),
            AchievementState {
                unlocked: true,
                unlocked_at: Some("2026-02-15T14:30:00Z".to_string()),
            },
        );
        progress
            .stats
            .albums_played
            .push("12345".to_string());
        progress
            .stats
            .tracks_guessed_per_album
            .insert("12345".to_string(), vec!["111".to_string(), "222".to_string()]);

        let json = serde_json::to_string(&progress).unwrap();
        let deserialized: GameProgress = serde_json::from_str(&json).unwrap();

        assert_eq!(deserialized.stats.total_correct, 42);
        assert!(deserialized.achievements["first_meow"].unlocked);
        assert_eq!(deserialized.stats.albums_played, vec!["12345"]);
        assert_eq!(
            deserialized.stats.tracks_guessed_per_album["12345"],
            vec!["111", "222"]
        );
    }

    #[test]
    fn test_progress_deserializes_from_spec_format() {
        let json = r#"{
            "version": 1,
            "achievements": {
                "first_meow": {"unlocked": true, "unlockedAt": "2026-02-15T14:30:00Z"},
                "purrfect_streak": {"unlocked": false, "unlockedAt": null}
            },
            "stats": {
                "totalCorrect": 42,
                "albumsPlayed": ["album_1"],
                "tracksGuessedPerAlbum": {"album_1": ["track_1"]}
            },
            "settings": {
                "theme": "dark",
                "volume": 0.8
            }
        }"#;

        let progress: GameProgress = serde_json::from_str(json).unwrap();
        assert_eq!(progress.version, 1);
        assert_eq!(progress.stats.total_correct, 42);
        assert!(progress.achievements["first_meow"].unlocked);
        assert!(!progress.achievements["purrfect_streak"].unlocked);
    }

    #[test]
    fn test_persistence_round_trip_with_tempfile() {
        let progress = GameProgress::default();
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("save.json");

        let json = serde_json::to_string_pretty(&progress).unwrap();
        std::fs::write(&path, &json).unwrap();

        let contents = std::fs::read_to_string(&path).unwrap();
        let loaded: GameProgress = serde_json::from_str(&contents).unwrap();
        assert_eq!(loaded.version, progress.version);
        assert_eq!(loaded.settings.theme, progress.settings.theme);
    }
}

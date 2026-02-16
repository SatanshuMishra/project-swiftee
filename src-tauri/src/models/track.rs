use serde::{Deserialize, Serialize};

/// Deezer returns snake_case; frontend expects camelCase.
/// `deserialize` uses Rust field names (snake_case) which match Deezer.
/// `serialize` converts to camelCase for the frontend.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all(serialize = "camelCase"))]
pub struct Track {
    pub id: u64,
    pub title: String,
    pub title_short: String,
    pub duration: u32,
    #[serde(default)]
    pub preview: String,
    pub artist: Artist,
    /// Absent on tracks from `/album/{id}/tracks`; enriched by the command layer.
    #[serde(default)]
    pub album: Album,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all(serialize = "camelCase"))]
pub struct Artist {
    pub id: u64,
    pub name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all(serialize = "camelCase"))]
pub struct Album {
    #[serde(default)]
    pub id: u64,
    #[serde(default)]
    pub title: String,
    #[serde(default)]
    pub cover_medium: Option<String>,
}

/// Response wrapper for Deezer paginated data
#[derive(Debug, Deserialize)]
pub struct DeezerResponse<T> {
    pub data: Vec<T>,
}

/// Full album detail from `/album/{id}`, includes embedded tracks and track count.
#[derive(Debug, Deserialize)]
pub struct AlbumDetail {
    pub id: u64,
    pub title: String,
    #[serde(default)]
    pub cover_medium: Option<String>,
    pub nb_tracks: u32,
    pub tracks: DeezerResponse<Track>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_track_deserialize_from_deezer_json() {
        let json = r#"{
            "id": 1234,
            "title": "Enchanted (Taylor's Version)",
            "title_short": "Enchanted",
            "duration": 319,
            "preview": "https://cdns-preview-d.dzcdn.net/stream/c-123.mp3",
            "artist": {"id": 12246, "name": "Taylor Swift"},
            "album": {"id": 567, "title": "Speak Now (Taylor's Version)", "cover_medium": "https://example.com/cover.jpg"}
        }"#;

        let track: Track = serde_json::from_str(json).unwrap();
        assert_eq!(track.id, 1234);
        assert_eq!(track.title_short, "Enchanted");
        assert_eq!(track.artist.name, "Taylor Swift");
        assert_eq!(track.album.cover_medium.as_deref(), Some("https://example.com/cover.jpg"));
    }

    #[test]
    fn test_track_serializes_to_camel_case() {
        let track = Track {
            id: 1,
            title: "Test".to_string(),
            title_short: "Test".to_string(),
            duration: 30,
            preview: "https://example.com".to_string(),
            artist: Artist { id: 1, name: "Artist".to_string() },
            album: Album { id: 1, title: "Album".to_string(), cover_medium: None },
        };

        let json = serde_json::to_value(&track).unwrap();
        assert!(json.get("titleShort").is_some());
        assert!(json.get("title_short").is_none());
    }

    #[test]
    fn test_album_missing_cover_defaults_to_none() {
        let json = r#"{"id": 1, "title": "Test Album"}"#;
        let album: Album = serde_json::from_str(json).unwrap();
        assert!(album.cover_medium.is_none());
    }

    #[test]
    fn test_deezer_response_deserializes() {
        let json = r#"{"data": [{"id": 1, "title": "Album One"}, {"id": 2, "title": "Album Two"}]}"#;
        let response: DeezerResponse<Album> = serde_json::from_str(json).unwrap();
        assert_eq!(response.data.len(), 2);
        assert_eq!(response.data[0].title, "Album One");
    }

    /// Deezer's /album/{id}/tracks endpoint does NOT include `album` on tracks.
    /// Track must deserialize with a default album when the field is absent.
    #[test]
    fn test_track_deserializes_without_album_field() {
        let json = r#"{
            "id": 3579685431,
            "title": "The Fate of Ophelia",
            "title_short": "The Fate of Ophelia",
            "duration": 226,
            "preview": "https://cdnt-preview.dzcdn.net/stream/c-123.mp3",
            "artist": {"id": 12246, "name": "Taylor Swift"}
        }"#;

        let track: Track = serde_json::from_str(json).unwrap();
        assert_eq!(track.id, 3579685431);
        assert_eq!(track.title_short, "The Fate of Ophelia");
        assert_eq!(track.album.id, 0);
        assert_eq!(track.album.title, "");
    }

    /// Deezer album detail endpoint returns nb_tracks, needed for completionist achievement.
    #[test]
    fn test_album_detail_deserializes() {
        let json = r#"{
            "id": 829966251,
            "title": "The Life of a Showgirl",
            "cover_medium": "https://e.dzcdn.net/images/cover/abc/250x250.jpg",
            "nb_tracks": 12,
            "tracks": {
                "data": [
                    {
                        "id": 111,
                        "title": "Track One",
                        "title_short": "Track One",
                        "duration": 200,
                        "preview": "https://cdnt-preview.dzcdn.net/stream/c-111.mp3",
                        "artist": {"id": 12246, "name": "Taylor Swift"}
                    }
                ]
            }
        }"#;

        let detail: AlbumDetail = serde_json::from_str(json).unwrap();
        assert_eq!(detail.id, 829966251);
        assert_eq!(detail.title, "The Life of a Showgirl");
        assert_eq!(detail.nb_tracks, 12);
        assert_eq!(detail.tracks.data.len(), 1);
        assert_eq!(detail.tracks.data[0].title, "Track One");
    }

    #[test]
    fn test_track_with_album_enrichment() {
        // Simulate track from album endpoint (no album) enriched with album info
        let json = r#"{
            "id": 111,
            "title": "Track One",
            "title_short": "Track One",
            "duration": 200,
            "preview": "https://example.com/preview.mp3",
            "artist": {"id": 12246, "name": "Taylor Swift"}
        }"#;

        let mut track: Track = serde_json::from_str(json).unwrap();
        let album = Album {
            id: 999,
            title: "Test Album".to_string(),
            cover_medium: Some("https://example.com/cover.jpg".to_string()),
        };
        track.album = album;

        assert_eq!(track.album.id, 999);
        assert_eq!(track.album.title, "Test Album");

        // Verify it serializes correctly for the frontend
        let serialized = serde_json::to_value(&track).unwrap();
        assert_eq!(serialized["album"]["coverMedium"], "https://example.com/cover.jpg");
    }
}

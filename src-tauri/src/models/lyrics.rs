use serde::{Deserialize, Serialize};

/// What LRCLIB returns (only fields we care about)
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LrclibResponse {
    pub id: u64,
    pub track_name: String,
    pub artist_name: String,
    pub album_name: String,
    pub duration: f64,
    pub instrumental: bool,
    pub plain_lyrics: Option<String>,
}

/// What we return to the frontend
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TrackLyrics {
    pub lrclib_id: u64,
    pub lines: Vec<String>,
    pub line_count: usize,
    pub source_track: String,
    pub source_album: String,
}

/// Batch request input from frontend
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LyricsBatchRequest {
    pub track_id: u64,
    pub track_title: String,
    pub artist_name: String,
    pub album_name: Option<String>,
    pub duration_secs: Option<u32>,
}

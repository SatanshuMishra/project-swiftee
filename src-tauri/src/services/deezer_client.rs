use std::time::Duration;

use crate::models::error::AppError;
use crate::models::track::{Album, AlbumDetail, DeezerResponse, Track};

const DEEZER_BASE_URL: &str = "https://api.deezer.com";
const TAYLOR_SWIFT_ID: u64 = 12246;
const REQUEST_TIMEOUT_SECS: u64 = 10;

pub struct DeezerClient {
    client: reqwest::Client,
}

impl Default for DeezerClient {
    fn default() -> Self {
        Self::new()
    }
}

impl DeezerClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(REQUEST_TIMEOUT_SECS))
            .https_only(true)
            .build()
            .expect("Failed to create HTTP client");

        Self { client }
    }

    pub async fn fetch_albums(&self) -> Result<Vec<Album>, AppError> {
        let url = format!(
            "{}/artist/{}/albums?limit=100",
            DEEZER_BASE_URL, TAYLOR_SWIFT_ID
        );
        let response: DeezerResponse<Album> = self
            .client
            .get(&url)
            .send()
            .await?
            .json()
            .await?;
        Ok(response.data)
    }

    /// Fetches `/album/{id}` and returns tracks enriched with album metadata.
    /// The tracks endpoint alone omits the `album` field, so we use the full
    /// album detail endpoint and inject album info into each track.
    pub async fn fetch_album_tracks(&self, album_id: u64) -> Result<(Vec<Track>, u32), AppError> {
        if album_id == 0 {
            return Err(AppError::ApiError("Invalid album ID".to_string()));
        }

        let url = format!("{}/album/{}", DEEZER_BASE_URL, album_id);
        let detail: AlbumDetail = self
            .client
            .get(&url)
            .send()
            .await?
            .json()
            .await?;

        let album = Album {
            id: detail.id,
            title: detail.title,
            cover_medium: detail.cover_medium,
        };

        let tracks: Vec<Track> = detail
            .tracks
            .data
            .into_iter()
            .map(|mut t| {
                t.album = album.clone();
                t
            })
            .collect();

        Ok((tracks, detail.nb_tracks))
    }

    pub async fn fetch_top_tracks(&self) -> Result<Vec<Track>, AppError> {
        let url = format!(
            "{}/artist/{}/top?limit=100",
            DEEZER_BASE_URL, TAYLOR_SWIFT_ID
        );
        let response: DeezerResponse<Track> = self
            .client
            .get(&url)
            .send()
            .await?
            .json()
            .await?;
        Ok(response.data)
    }
}

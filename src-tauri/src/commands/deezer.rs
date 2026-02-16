use serde::{Deserialize, Serialize};
use tauri::State;

use crate::models::error::AppError;
use crate::models::track::{Album, Track};
use crate::state::AppState;

/// Response for fetch_album_tracks, includes track count for completionist achievement.
#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AlbumTracksResponse {
    pub tracks: Vec<Track>,
    pub total_tracks: u32,
}

#[tauri::command]
pub async fn fetch_albums(state: State<'_, AppState>) -> Result<Vec<Album>, AppError> {
    // Check cache
    {
        let cache = state.cache.lock().unwrap();
        if let Some(cached) = cache.get("albums") {
            return serde_json::from_value(cached.clone()).map_err(AppError::from);
        }
    }

    // Rate limit
    {
        let mut limiter = state.rate_limiter.lock().unwrap();
        limiter.try_acquire()?;
    }

    // Fetch
    let albums = state.deezer_client.fetch_albums().await?;

    // Cache
    {
        let mut cache = state.cache.lock().unwrap();
        let value = serde_json::to_value(&albums)?;
        cache.set("albums".to_string(), value);
    }

    Ok(albums)
}

#[tauri::command]
pub async fn fetch_album_tracks(
    album_id: u64,
    state: State<'_, AppState>,
) -> Result<AlbumTracksResponse, AppError> {
    if album_id == 0 {
        return Err(AppError::ApiError("Invalid album ID".to_string()));
    }

    let cache_key = format!("album_tracks:{}", album_id);

    // Check cache
    {
        let cache = state.cache.lock().unwrap();
        if let Some(cached) = cache.get(&cache_key) {
            return serde_json::from_value(cached.clone()).map_err(AppError::from);
        }
    }

    // Rate limit
    {
        let mut limiter = state.rate_limiter.lock().unwrap();
        limiter.try_acquire()?;
    }

    // Fetch (uses /album/{id} to get both tracks and album metadata)
    let (tracks, total_tracks) = state.deezer_client.fetch_album_tracks(album_id).await?;

    let response = AlbumTracksResponse {
        tracks,
        total_tracks,
    };

    // Cache
    {
        let mut cache = state.cache.lock().unwrap();
        let value = serde_json::to_value(&response)?;
        cache.set(cache_key, value);
    }

    Ok(response)
}

#[tauri::command]
pub async fn fetch_top_tracks(state: State<'_, AppState>) -> Result<Vec<Track>, AppError> {
    // Check cache
    {
        let cache = state.cache.lock().unwrap();
        if let Some(cached) = cache.get("top_tracks") {
            return serde_json::from_value(cached.clone()).map_err(AppError::from);
        }
    }

    // Rate limit
    {
        let mut limiter = state.rate_limiter.lock().unwrap();
        limiter.try_acquire()?;
    }

    // Fetch
    let tracks = state.deezer_client.fetch_top_tracks().await?;

    // Cache
    {
        let mut cache = state.cache.lock().unwrap();
        let value = serde_json::to_value(&tracks)?;
        cache.set("top_tracks".to_string(), value);
    }

    Ok(tracks)
}

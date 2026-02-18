use std::collections::HashMap;

use tauri::State;

use crate::models::error::AppError;
use crate::models::lyrics::{LyricsBatchRequest, TrackLyrics};
use crate::state::AppState;

#[tauri::command]
pub async fn fetch_lyrics(
    deezer_track_id: u64,
    track_title: String,
    artist_name: String,
    album_name: Option<String>,
    duration_secs: Option<u32>,
    state: State<'_, AppState>,
) -> Result<TrackLyrics, AppError> {
    let cache_key = format!("lyrics:{}", deezer_track_id);

    // Check cache
    {
        let cache = state.cache.lock().unwrap();
        if let Some(cached) = cache.get(&cache_key) {
            if cached.is_null() {
                return Err(AppError::LyricsNotFound);
            }
            if let Ok(lyrics) = serde_json::from_value::<TrackLyrics>(cached.clone()) {
                return Ok(lyrics);
            }
        }
    }

    let result = state
        .lrclib_client
        .fetch_lyrics(
            &track_title,
            &artist_name,
            album_name.as_deref(),
            duration_secs,
        )
        .await;

    match result {
        Ok(lyrics) => {
            let value = serde_json::to_value(&lyrics).unwrap_or(serde_json::Value::Null);
            let mut cache = state.cache.lock().unwrap();
            cache.set(cache_key, value);
            Ok(lyrics)
        }
        Err(AppError::LyricsNotFound) => {
            let mut cache = state.cache.lock().unwrap();
            cache.set(cache_key, serde_json::Value::Null);
            Err(AppError::LyricsNotFound)
        }
        Err(e) => Err(e),
    }
}

#[tauri::command]
pub async fn fetch_lyrics_batch(
    tracks: Vec<LyricsBatchRequest>,
    state: State<'_, AppState>,
) -> Result<HashMap<u64, Option<TrackLyrics>>, AppError> {
    let mut results: HashMap<u64, Option<TrackLyrics>> = HashMap::new();
    let mut to_fetch: Vec<&LyricsBatchRequest> = Vec::new();

    // Check cache first for each track
    {
        let cache = state.cache.lock().unwrap();
        for track in &tracks {
            let cache_key = format!("lyrics:{}", track.track_id);
            if let Some(cached) = cache.get(&cache_key) {
                if cached.is_null() {
                    results.insert(track.track_id, None);
                } else if let Ok(lyrics) =
                    serde_json::from_value::<TrackLyrics>(cached.clone())
                {
                    results.insert(track.track_id, Some(lyrics));
                } else {
                    to_fetch.push(track);
                }
            } else {
                to_fetch.push(track);
            }
        }
    }

    // Fetch in batches of 5 concurrent using futures::future::join_all
    let lrclib = &state.lrclib_client;
    for chunk in to_fetch.chunks(5) {
        let futures: Vec<_> = chunk
            .iter()
            .map(|req| async {
                let result = lrclib
                    .fetch_lyrics(
                        &req.track_title,
                        &req.artist_name,
                        req.album_name.as_deref(),
                        req.duration_secs,
                    )
                    .await;
                (req.track_id, result)
            })
            .collect();

        let batch_results = futures::future::join_all(futures).await;

        let mut cache = state.cache.lock().unwrap();
        for (track_id, result) in batch_results {
            let cache_key = format!("lyrics:{}", track_id);
            match result {
                Ok(lyrics) => {
                    let value =
                        serde_json::to_value(&lyrics).unwrap_or(serde_json::Value::Null);
                    cache.set(cache_key, value);
                    results.insert(track_id, Some(lyrics));
                }
                Err(AppError::LyricsNotFound) => {
                    cache.set(cache_key, serde_json::Value::Null);
                    results.insert(track_id, None);
                }
                Err(_) => {
                    // Service errors: don't cache, mark as None
                    results.insert(track_id, None);
                }
            }
        }
    }

    Ok(results)
}

use regex::Regex;
use std::time::Duration;

use crate::models::error::AppError;
use crate::models::lyrics::{LrclibResponse, TrackLyrics};

const LRCLIB_BASE_URL: &str = "https://lrclib.net/api";
const REQUEST_TIMEOUT_SECS: u64 = 10;

pub struct LrclibClient {
    client: reqwest::Client,
}

impl Default for LrclibClient {
    fn default() -> Self {
        Self::new()
    }
}

impl LrclibClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(REQUEST_TIMEOUT_SECS))
            .user_agent("SwiftieQuiz/1.0.0 (https://github.com/satanshumishra/swiftie-quiz)")
            .build()
            .expect("Failed to create LRCLIB HTTP client");

        Self { client }
    }

    /// 3-step cascading lookup for lyrics
    pub async fn fetch_lyrics(
        &self,
        track_title: &str,
        artist_name: &str,
        album_name: Option<&str>,
        duration_secs: Option<u32>,
    ) -> Result<TrackLyrics, AppError> {
        // Step 1: Exact match
        if let Some(lyrics) = self
            .try_exact_match(track_title, artist_name, album_name, duration_secs)
            .await?
        {
            return Ok(lyrics);
        }

        // Step 2: Normalized match
        let normalized = normalise_title(track_title);
        if normalized != track_title.to_lowercase().trim() {
            if let Some(lyrics) = self
                .try_exact_match(&normalized, artist_name, None, None)
                .await?
            {
                return Ok(lyrics);
            }
        }

        // Step 3: Fuzzy search
        if let Some(lyrics) = self
            .try_fuzzy_search(&normalized, artist_name, duration_secs)
            .await?
        {
            return Ok(lyrics);
        }

        Err(AppError::LyricsNotFound)
    }

    async fn try_exact_match(
        &self,
        track_name: &str,
        artist_name: &str,
        album_name: Option<&str>,
        duration_secs: Option<u32>,
    ) -> Result<Option<TrackLyrics>, AppError> {
        let mut params = vec![
            ("track_name", track_name.to_string()),
            ("artist_name", artist_name.to_string()),
        ];
        if let Some(album) = album_name {
            params.push(("album_name", album.to_string()));
        }
        if let Some(duration) = duration_secs {
            params.push(("duration", duration.to_string()));
        }

        let response = self
            .client
            .get(format!("{}/get", LRCLIB_BASE_URL))
            .query(&params)
            .send()
            .await
            .map_err(|e| {
                if e.is_timeout() {
                    AppError::LyricsServiceUnavailable
                } else {
                    AppError::NetworkError(e.to_string())
                }
            })?;

        if response.status() == reqwest::StatusCode::NOT_FOUND {
            return Ok(None);
        }

        if response.status().is_server_error() {
            return Err(AppError::LyricsServiceUnavailable);
        }

        if !response.status().is_success() {
            return Ok(None);
        }

        let data: LrclibResponse = match response.json().await {
            Ok(d) => d,
            Err(_) => return Ok(None),
        };

        if data.instrumental {
            return Ok(None);
        }

        match data.plain_lyrics {
            Some(ref plain) if !plain.trim().is_empty() => {
                let lines = process_plain_lyrics(plain);
                if lines.is_empty() {
                    return Ok(None);
                }
                let line_count = lines.len();
                Ok(Some(TrackLyrics {
                    lrclib_id: data.id,
                    lines,
                    line_count,
                    source_track: data.track_name,
                    source_album: data.album_name,
                }))
            }
            _ => Ok(None),
        }
    }

    async fn try_fuzzy_search(
        &self,
        track_name: &str,
        artist_name: &str,
        duration_secs: Option<u32>,
    ) -> Result<Option<TrackLyrics>, AppError> {
        let params = vec![
            ("track_name", track_name.to_string()),
            ("artist_name", artist_name.to_string()),
        ];

        let response = self
            .client
            .get(format!("{}/search", LRCLIB_BASE_URL))
            .query(&params)
            .send()
            .await
            .map_err(|e| {
                if e.is_timeout() {
                    AppError::LyricsServiceUnavailable
                } else {
                    AppError::NetworkError(e.to_string())
                }
            })?;

        if !response.status().is_success() {
            return Ok(None);
        }

        let results: Vec<LrclibResponse> = match response.json().await {
            Ok(d) => d,
            Err(_) => return Ok(None),
        };

        // Filter to results with plain lyrics, non-instrumental
        let with_lyrics: Vec<&LrclibResponse> = results
            .iter()
            .filter(|r| {
                !r.instrumental
                    && r.plain_lyrics
                        .as_ref()
                        .map(|l| !l.trim().is_empty())
                        .unwrap_or(false)
            })
            .collect();

        if with_lyrics.is_empty() {
            return Ok(None);
        }

        // Pick closest duration match if we have a target duration
        let best = if let Some(target) = duration_secs {
            with_lyrics
                .iter()
                .min_by_key(|r| (r.duration.round() as i64 - target as i64).unsigned_abs())
                .unwrap()
        } else {
            with_lyrics.first().unwrap()
        };

        let plain = best.plain_lyrics.as_ref().unwrap();
        let lines = process_plain_lyrics(plain);
        if lines.is_empty() {
            return Ok(None);
        }
        let line_count = lines.len();
        Ok(Some(TrackLyrics {
            lrclib_id: best.id,
            lines,
            line_count,
            source_track: best.track_name.clone(),
            source_album: best.album_name.clone(),
        }))
    }
}

/// Remove all parenthetical suffixes from a title, repeatedly.
/// "All Too Well (10 Minute Version) (Taylor's Version)" -> "All Too Well"
pub fn normalise_title(title: &str) -> String {
    let re = Regex::new(r"\s*\([^)]*\)\s*$").unwrap();
    let mut result = title.to_string();
    loop {
        let stripped = re.replace(&result, "").to_string();
        if stripped == result {
            break;
        }
        result = stripped;
    }
    result.trim().to_string()
}

/// Split plain lyrics on newlines, trim, filter empty and section headers.
pub fn process_plain_lyrics(raw: &str) -> Vec<String> {
    let section_header = Regex::new(r"^\[.*\]$").unwrap();
    raw.split('\n')
        .map(|line| line.trim().to_string())
        .filter(|line| !line.is_empty())
        .filter(|line| !section_header.is_match(line))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalise_title_no_parens() {
        assert_eq!(normalise_title("Cruel Summer"), "Cruel Summer");
    }

    #[test]
    fn test_normalise_title_single_paren() {
        assert_eq!(
            normalise_title("Enchanted (Taylor's Version)"),
            "Enchanted"
        );
    }

    #[test]
    fn test_normalise_title_multiple_parens() {
        assert_eq!(
            normalise_title(
                "All Too Well (10 Minute Version) (Taylor's Version) (From The Vault)"
            ),
            "All Too Well"
        );
    }

    #[test]
    fn test_normalise_title_feat() {
        assert_eq!(normalise_title("22 (feat. Ed Sheeran)"), "22");
    }

    #[test]
    fn test_normalise_title_lowercase() {
        assert_eq!(
            normalise_title("willow (dancing witch version) (bonus track)"),
            "willow"
        );
    }

    #[test]
    fn test_process_plain_lyrics_basic() {
        let raw = "Line one\nLine two\n\nLine three";
        let lines = process_plain_lyrics(raw);
        assert_eq!(lines, vec!["Line one", "Line two", "Line three"]);
    }

    #[test]
    fn test_process_plain_lyrics_strips_headers() {
        let raw = "[Verse 1]\nFirst line\n[Chorus]\nChorus line\n[Outro]\nLast line";
        let lines = process_plain_lyrics(raw);
        assert_eq!(lines, vec!["First line", "Chorus line", "Last line"]);
    }

    #[test]
    fn test_process_plain_lyrics_trims_whitespace() {
        let raw = "  hello  \n  world  \n   \n  foo  ";
        let lines = process_plain_lyrics(raw);
        assert_eq!(lines, vec!["hello", "world", "foo"]);
    }
}

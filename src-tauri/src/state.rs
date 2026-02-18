use std::sync::Mutex;

use crate::services::cache::ResponseCache;
use crate::services::deezer_client::DeezerClient;
use crate::services::lrclib_client::LrclibClient;
use crate::services::rate_limiter::RateLimiter;

pub struct AppState {
    pub deezer_client: DeezerClient,
    pub lrclib_client: LrclibClient,
    pub cache: Mutex<ResponseCache>,
    pub rate_limiter: Mutex<RateLimiter>,
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}

impl AppState {
    pub fn new() -> Self {
        Self {
            deezer_client: DeezerClient::new(),
            lrclib_client: LrclibClient::new(),
            cache: Mutex::new(ResponseCache::new()),
            rate_limiter: Mutex::new(RateLimiter::new()),
        }
    }
}

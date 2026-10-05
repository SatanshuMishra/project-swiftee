pub mod cache;
pub mod deezer_client;
pub mod lrclib_client;
pub mod rate_limiter;
pub mod track_filter;

pub(crate) fn http_client_builder() -> reqwest::ClientBuilder {
    let _ = rustls::crypto::ring::default_provider().install_default();
    reqwest::Client::builder()
}

#[cfg(test)]
mod tests {
    use super::deezer_client::DeezerClient;
    use super::lrclib_client::LrclibClient;

    #[test]
    fn http_clients_build_with_installed_crypto_provider() {
        let _ = DeezerClient::new();
        let _ = LrclibClient::new();
        assert!(rustls::crypto::CryptoProvider::get_default().is_some());
    }
}

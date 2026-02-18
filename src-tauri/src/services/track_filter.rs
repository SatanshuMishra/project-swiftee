use crate::models::track::Track;

const MIN_DURATION_SECS: u32 = 60;

/// Case-insensitive patterns in `title_version` that indicate a remix or
/// derivative version by someone other than the original artist.
const REMIX_PATTERNS: &[&str] = &["remix", "version by", "karaoke", "instrumental"];

/// Case-insensitive patterns in the full `title` that indicate non-song content
/// (commentary, spoken interludes, voice memos, etc.).
const NON_SONG_PATTERNS: &[&str] = &[
    "track-by-track",
    "track by track",
    "commentary",
    "voice memo",
    "spoken word",
    "skit",
    "instrumental",
];

/// Returns `true` if the track is a legitimate song that should appear in the
/// quiz pool.
///
/// Discards:
/// - Remixes / karaoke / instrumental versions (detected via `title_version`)
/// - Non-song content such as commentary or voice memos (detected via `title`)
/// - Tracks shorter than 60 seconds (interludes, transitions, sound effects)
pub fn is_playable_song(track: &Track) -> bool {
    if has_remix_version(&track.title_version) {
        return false;
    }
    if track.duration < MIN_DURATION_SECS {
        return false;
    }
    if has_non_song_keyword(&track.title) {
        return false;
    }
    true
}

fn has_remix_version(title_version: &str) -> bool {
    let lower = title_version.to_lowercase();
    if lower.trim().is_empty() {
        return false;
    }
    REMIX_PATTERNS.iter().any(|pat| lower.contains(pat))
}

fn has_non_song_keyword(title: &str) -> bool {
    let lower = title.to_lowercase();
    NON_SONG_PATTERNS.iter().any(|pat| lower.contains(pat))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::track::{Album, Artist};

    fn make_track(title: &str, title_version: &str, duration: u32) -> Track {
        Track {
            id: 1,
            title: title.to_string(),
            title_short: title.to_string(),
            title_version: title_version.to_string(),
            duration,
            preview: "https://example.com/preview.mp3".to_string(),
            artist: Artist {
                id: 12246,
                name: "Taylor Swift".to_string(),
            },
            album: Album {
                id: 1,
                title: "Test Album".to_string(),
                cover_medium: None,
            },
        }
    }

    // ── Songs that SHOULD be kept ──────────────────────────────────────

    #[test]
    fn keeps_standard_song() {
        let track = make_track("Cruel Summer", "", 179);
        assert!(is_playable_song(&track));
    }

    #[test]
    fn keeps_taylors_version() {
        let track = make_track("Love Story (Taylor's Version)", "", 235);
        assert!(is_playable_song(&track));
    }

    #[test]
    fn keeps_from_the_vault() {
        let track = make_track(
            "Mr. Perfectly Fine (From The Vault) (Taylor's Version)",
            "",
            244,
        );
        assert!(is_playable_song(&track));
    }

    #[test]
    fn keeps_10_minute_version() {
        let track = make_track(
            "All Too Well (10 Minute Version) (Taylor's Version) (From The Vault)",
            "",
            613,
        );
        assert!(is_playable_song(&track));
    }

    #[test]
    fn keeps_feature_collab() {
        let track = make_track("Life of a Showgirl (with Sabrina Carpenter)", "", 190);
        assert!(is_playable_song(&track));
    }

    #[test]
    fn keeps_acoustic_version() {
        let track = make_track("Lover (Acoustic)", "(Acoustic)", 210);
        assert!(is_playable_song(&track));
    }

    #[test]
    fn keeps_live_version() {
        let track = make_track("Love Story (Live)", "(Live)", 245);
        assert!(is_playable_song(&track));
    }

    #[test]
    fn keeps_deluxe_bonus_track() {
        let track = make_track("New Romantics", "", 231);
        assert!(is_playable_song(&track));
    }

    // ── Songs that SHOULD be filtered ──────────────────────────────────

    #[test]
    fn discards_chainsmokers_remix() {
        let track = make_track(
            "The Fate of Ophelia (The Chainsmokers Remix)",
            "(The Chainsmokers Remix)",
            226,
        );
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn discards_generic_remix() {
        let track = make_track(
            "I Knew You Were Trouble (Remix)",
            "(Remix)",
            219,
        );
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn discards_karaoke() {
        let track = make_track(
            "Shake It Off (Karaoke Version)",
            "(Karaoke Version)",
            219,
        );
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn discards_instrumental() {
        let track = make_track(
            "Anti-Hero (Instrumental)",
            "(Instrumental)",
            200,
        );
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn discards_short_track() {
        let track = make_track("Short Interlude", "", 45);
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn discards_exactly_59_seconds() {
        let track = make_track("Almost There", "", 59);
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn keeps_exactly_60_seconds() {
        let track = make_track("Just Long Enough", "", 60);
        assert!(is_playable_song(&track));
    }

    #[test]
    fn discards_track_by_track() {
        let track = make_track("Love Story - Track-by-Track", "", 120);
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn discards_track_by_track_spaced() {
        let track = make_track("Love Story - Track by Track", "", 120);
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn discards_commentary() {
        let track = make_track("Fearless Commentary", "", 300);
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn discards_voice_memo() {
        let track = make_track("cardigan Voice Memo", "", 200);
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn discards_spoken_word() {
        let track = make_track("A Spoken Word Piece", "", 180);
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn discards_skit() {
        let track = make_track("Interlude Skit", "", 90);
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn discards_instrumental_in_title_only() {
        // title_version is empty but "Instrumental" appears in the title
        let track = make_track("Anti-Hero (Instrumental)", "", 200);
        assert!(!is_playable_song(&track));
    }

    // ── Edge cases ─────────────────────────────────────────────────────

    #[test]
    fn whitespace_only_title_version_is_kept() {
        let track = make_track("Blank Space", "   ", 231);
        assert!(is_playable_song(&track));
    }

    #[test]
    fn remix_detection_is_case_insensitive() {
        let track = make_track(
            "Bad Blood (REMIX)",
            "(REMIX)",
            211,
        );
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn non_song_detection_is_case_insensitive() {
        let track = make_track("Fearless COMMENTARY", "", 300);
        assert!(!is_playable_song(&track));
    }

    #[test]
    fn taylors_version_in_title_version_is_kept() {
        // Deezer may populate title_version with "(Taylor's Version)" — must not
        // trigger the "version by" remix pattern.
        let track = make_track("Love Story (Taylor's Version)", "(Taylor's Version)", 235);
        assert!(is_playable_song(&track));
    }
}

use semver::Version;

const FIRST_LINE_NEEDING_MACOS_12: (u64, u64) = (0, 3);
const MACOS_12: (u64, u64) = (12, 0);

pub fn is_update_offered(current: &Version, update: &Version, macos: Option<(u64, u64)>) -> bool {
    update > current && !needs_newer_macos(update, macos)
}

fn needs_newer_macos(update: &Version, macos: Option<(u64, u64)>) -> bool {
    (update.major, update.minor) >= FIRST_LINE_NEEDING_MACOS_12
        && macos.is_some_and(|running| running < MACOS_12)
}

#[cfg(target_os = "macos")]
pub fn running_macos_version() -> Option<(u64, u64)> {
    let version = objc2_foundation::NSProcessInfo::processInfo().operatingSystemVersion();
    Some((
        u64::try_from(version.majorVersion).ok()?,
        u64::try_from(version.minorVersion).ok()?,
    ))
}

#[cfg(not(target_os = "macos"))]
pub fn running_macos_version() -> Option<(u64, u64)> {
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    fn offered(current: &str, update: &str, macos: Option<(u64, u64)>) -> bool {
        is_update_offered(
            &Version::parse(current).unwrap(),
            &Version::parse(update).unwrap(),
            macos,
        )
    }

    #[test]
    fn rejects_equal_version() {
        assert!(!offered("0.2.0", "0.2.0", None));
    }

    #[test]
    fn rejects_older_version() {
        assert!(!offered("0.2.0", "0.1.5", None));
    }

    #[test]
    fn accepts_newer_patch() {
        assert!(offered("0.2.0", "0.2.1", None));
    }

    #[test]
    fn accepts_newer_minor() {
        assert!(offered("0.2.0", "0.3.0", None));
    }

    #[test]
    fn accepts_newer_major() {
        assert!(offered("0.2.0", "1.0.0", None));
    }

    #[test]
    fn withholds_the_flutter_release_from_macos_11() {
        assert!(!offered("0.2.4", "0.3.0", Some((11, 7))));
    }

    #[test]
    fn withholds_the_flutter_release_when_macos_reports_compatibility_version() {
        assert!(!offered("0.2.4", "0.3.0", Some((10, 16))));
    }

    #[test]
    fn withholds_every_later_release_from_macos_11() {
        assert!(!offered("0.2.4", "0.3.5", Some((11, 0))));
        assert!(!offered("0.2.4", "1.0.0", Some((11, 0))));
        assert!(!offered("0.2.4", "0.3.0-rc.1", Some((11, 0))));
    }

    #[test]
    fn offers_the_flutter_release_on_macos_12_and_later() {
        assert!(offered("0.2.4", "0.3.0", Some((12, 0))));
        assert!(offered("0.2.4", "0.3.0", Some((26, 1))));
    }

    #[test]
    fn offers_the_flutter_release_on_windows() {
        assert!(offered("0.2.4", "0.3.0", None));
    }

    #[test]
    fn still_offers_0_2_patches_on_macos_11() {
        assert!(offered("0.2.4", "0.2.5", Some((11, 0))));
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn reads_the_running_macos_version() {
        let (major, _) = running_macos_version().unwrap();
        assert!(major >= 11);
    }

    #[cfg(not(target_os = "macos"))]
    #[test]
    fn reports_no_macos_version_elsewhere() {
        assert_eq!(running_macos_version(), None);
    }
}

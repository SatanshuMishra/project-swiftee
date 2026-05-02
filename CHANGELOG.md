# Changelog

All notable changes to Swiftie Quiz are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and this project adheres to
[Semantic Versioning](https://semver.org/).

## [0.2.1] - 2026-05-02

### Fixed
- **macOS first-install path.** The Tauri bundler now ad-hoc signs the
  bundle (`Contents/_CodeSignature/CodeResources` is generated alongside
  the linker-signed binary) so that Gatekeeper categorizes the app as
  "from an unidentified developer" rather than "damaged." The "Open
  Anyway" button in System Settings → Privacy & Security is now
  reachable on the first install. v0.2.0 erroneously shipped with a
  malformed signature that triggered the "is damaged" message and hid
  the Open Anyway path. (Apple Developer ID and notarization remain
  deferred — adopting them would eliminate the "Open Anyway" step
  entirely; tracked as future work.)

### Changed
- `INSTALL.md` macOS walkthrough refreshed to reflect ad-hoc signing
  and use macOS-version-agnostic dialog wording (Sequoia and Tahoe
  show different text for the same Gatekeeper class).

### Migrating from v0.2.0
- Existing v0.2.0 installs that already worked around the issue
  locally (via `xattr -cr` + `codesign --force --deep --sign -`)
  auto-upgrade silently via the in-app updater. The updater downloads
  the new bundle from inside the running app, which doesn't apply the
  `com.apple.quarantine` xattr, so subsequent updates do not re-trigger
  Gatekeeper at all.

## [0.2.0] - 2026-05-01

### Added
- **Auto-update support.** The app now checks GitHub Releases for new versions
  on launch and every 6 hours while running. When a newer version is available,
  a small badge appears in the corner of the window. Click it to read the
  release notes and choose to download and install — no silent downloads.
- **Save-file backups.** The app keeps the three most recent automatic backups
  of your save file. You can review and restore them from Settings → Backups.
- **Settings → Updates section.** Lets you toggle automatic update checks,
  trigger a check manually, and see when the last check ran.
- **Update verification.** Every downloaded update is cryptographically
  verified against an embedded minisign public key before installation.
  Updates that fail verification are rejected.

### Changed
- Save-file schema bumped from v2 → v3 to add the updater preferences slice
  (auto-check toggle, last-checked timestamp, skipped versions, remind-later
  cooldown). Migration is automatic and your achievements / stats / settings
  are preserved. A timestamped backup is created before any migration runs.

### System requirements
- macOS 11.0 (Big Sur) or later, Apple Silicon (M1+)
- Windows 10 build 1809 or later, x86_64

### Migrating from v0.1.0
You can install v0.2.0 over the top of an existing v0.1.0 install — your save
data is stored outside the install directory and will be preserved
automatically. See [docs/INSTALL.md](docs/INSTALL.md) for first-install
warnings and click-through walkthroughs.

## [0.1.0] - prior

Initial manual distribution. (No public changelog was kept.)

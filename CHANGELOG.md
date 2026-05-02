# Changelog

All notable changes to Swiftie Quiz are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and this project adheres to
[Semantic Versioning](https://semver.org/).

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

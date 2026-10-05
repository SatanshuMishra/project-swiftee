# Changelog

All notable changes to Swiftie Quiz are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and this project adheres to
[Semantic Versioning](https://semver.org/).

## [0.3.0] - 2026-10-05

### Updating from v0.2.x
- The in-app updater offers this version like any other update. It installs it in place and reopens the app, and your progress, achievements and settings carry over.
- This version needs macOS 12 or later. On macOS 11, v0.2.4 does not offer it. Earlier versions do, so on macOS 11 decline it, or update to v0.2.4 first.

### Changed
- **Rebuilt in Flutter.** The screens, rules and save file are the same. On a Mac, the app now needs macOS 12 or later.
- **A redrawn cat.** The cat icon and the loading cat have a new design.

### Fixed
- **Every album loads.** The album list now follows Deezer's pages, so albums after the first hundred appear.
- **Song previews keep working in long sessions.** A preview link is refreshed when it expires, instead of failing after about 15 minutes.
- **Lyric lookups are gentler on LRCLIB.** They identify the app and wait when LRCLIB asks it to slow down.

## [0.2.4] - 2026-10-05

### Changed
- **Macs on macOS 11 stay on this version.** The next version of Swiftie Quiz needs macOS 12 or later. On macOS 11 the app no longer offers that update, so it cannot install a version that would not open. Updating to macOS 12 or later brings the update back. Windows, and Macs on macOS 12 or later, update as usual.

## [0.2.3] - 2026-10-05

### Updating from v0.2.2 or v0.2.1
- If this window keeps resetting before the download finishes, open Settings, untick "Automatically check for updates", click "Check now", then click the update badge, Download, and Install & Restart. You can turn automatic checks back on afterwards.
- On macOS, quit and reopen the app once after installing this update. From this version on, it restarts by itself.
- The save format is unchanged, so your progress, achievements and settings carry over.

### Fixed
- **Update checks no longer repeat every few seconds.** The app checks once at launch and then every six hours, as intended. Before, each check started the next one, so the update window kept resetting and a download could be lost before you installed it.
- **Install & Restart now restarts the app on macOS.** The update was installed, but the old version kept running until you quit. The app now reopens on the new version by itself.
- **Progress is no longer undone by an update check.** An achievement, score or setting changed while a check was in progress could be reverted when the check finished.
- **A downloaded update stays ready to install.** A later update check no longer replaces an update you have already downloaded, and cancelling a download no longer leaves a "Restart to install" badge behind.
- **Retry after a failed update check checks again.** Before, it tried to install an update that had never been found and failed with "No update to install".

## [0.2.2] - 2026-10-04

### Fixed
- **Lyrics mode loading.** The 30-second loading timeout is now cleared as
  soon as lyrics finish loading, instead of staying pending in the
  background, and the first round can no longer be scheduled after you
  leave the screen.
- **Timer and loading transitions.** The round timer and the loading
  screen now update in the same frame as the change that drives them,
  instead of briefly showing the previous value.

### Changed
- **Updated foundations.** The app now runs on React 19.3, Tauri 2.12,
  Vite 8, Motion 14 and the Rust 2024 edition, with network requests on
  reqwest 0.13. Gameplay is unchanged.
- **Checked before shipping.** Every release now runs the full test suite
  on macOS, Windows and Linux before it is built, and its update file is
  verified to list both macOS and Windows before it can be published.

### Migrating from v0.2.1
- Installed copies update through the in-app updater as usual. The save
  format is unchanged, so your progress, achievements and settings carry
  over as they are.

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

# Installation Guide

## System requirements

- **macOS:** 12 (Monterey) or later, Apple Silicon (M1, M2, M3, etc.).
  Intel Macs are not supported. macOS 11 is not supported from v0.3.0,
  because the app is now built with Flutter, which requires macOS 12.
- **Windows:** 10 or 11, 64-bit (x64).

## Downloading

Visit the [latest release page](https://github.com/SatanshuMishra/project-swiftee/releases/latest)
and download the appropriate file for your OS:

- **macOS:** `Project.Swiftie_<version>_aarch64.dmg` (the Open edition)
- **Windows, Ana edition:** `Project.Swiftie_<version>_x64-setup.exe`
- **Windows, Open edition:** `Project.Swiftie.Open_<version>_x64-setup.exe`

Project Swiftie, formerly Swiftie Quiz, comes in two editions. The Ana
edition is the one made for Ana; the Open edition is for everyone else.
On Windows, pick one: both editions install into the same folder and use
the same save, so installing the other edition later replaces the first
in place and keeps your progress.

## First-time install — please read

Project Swiftie is **ad-hoc code-signed** but not signed with an Apple Developer
ID and not notarized. This means your operating system will show a one-time
"unidentified developer" warning the first time you launch the app. Once you
allow the launch, every subsequent run is silent. Future in-app updates also
apply silently — the warning only appears for the very first install.

### macOS first-launch walkthrough

1. **Mount the DMG** by double-clicking it. Finder opens the disk image with
   the app icon and an Applications shortcut.
2. **Drag "Project Swiftie" to the Applications folder.** If you already have
   an older Project Swiftie, Finder asks whether to replace it — choose
   **Replace**. If you have "Swiftie Quiz" from before the rename, let its
   in-app updater update it instead, or drag it to the Trash first so you
   do not keep two copies. Your save data is stored separately and is
   **not** affected.
3. **Open the app from Applications.** macOS blocks the launch with an
   unidentified-developer dialog (the exact wording differs between macOS
   versions, but the buttons are usually **Done** / **Move to Trash** with
   no Open option). Click **Done**.
4. **Open System Settings → Privacy & Security.** Scroll to the Security
   section near the bottom. You'll see a line like:
   *"'Project Swiftie' was blocked from use because it is not from an
   identified developer."* Click **Open Anyway** next to it. macOS may ask
   you to authenticate with Touch ID or your password.
5. **Re-launch the app** from Applications. macOS shows one final
   confirmation: *"Are you sure you want to open it?"* — click **Open**.
6. The app launches. From now on, double-clicking the icon opens it normally
   — the dialog will not return.

> **Why is there an extra step?** Project Swiftie uses an ad-hoc code signature
> rather than an Apple Developer ID signature ($99/year). Both are
> cryptographically valid, but Apple only auto-trusts apps signed with a
> registered Developer ID. The first launch is the only time you'll see this
> friction; the in-app updater handles all future versions silently.

### Windows first-launch walkthrough

1. **Run the installer** by double-clicking the setup file you downloaded:
   `Project.Swiftie_<version>_x64-setup.exe` (Ana) or
   `Project.Swiftie.Open_<version>_x64-setup.exe` (Open).
2. **Microsoft Defender SmartScreen** will show a blue dialog:
   *Microsoft Defender SmartScreen prevented an unrecognized app from starting.*
3. Click the small **More info** link. The dialog expands and shows a
   **Run anyway** button. Click it.
4. The installer runs to completion. The app installs into
   `%LOCALAPPDATA%\Swiftie Quiz` (no Administrator prompt — per-user
   install). The folder keeps the app's former name so that earlier
   versions update in place. Installing over an earlier version, or over
   the other edition, replaces it in place.
5. Launch **Project Swiftie** from the Start menu. Subsequent launches are
   silent.

## Already installed? Updating to Project Swiftie

If you have Swiftie Quiz v0.3.0, you do not need to reinstall: the in-app
updater offers Project Swiftie like any other update. Windows copies update
to the Ana edition in their existing folder; macOS copies update to the
Open edition. Your save comes along.

- **Windows:** the Start menu and desktop shortcuts are renamed to Project
  Swiftie, and *Installed apps* lists Project Swiftie. The app still lives
  in `%LOCALAPPDATA%\Swiftie Quiz` and still runs as `swiftie-quiz.exe`.
- **macOS:** the app keeps its place as `Swiftie Quiz.app` in
  Applications, while its menu bar and Dock read Project Swiftie. You can
  rename it in Finder if you like; updates follow it either way.

## Updating to the Flutter version

Version 0.3.0 rebuilds the app in Flutter. If you already have Swiftie Quiz
v0.2.1 or later, you do not need to reinstall: the in-app updater offers
v0.3.0 like any other update, installs it, and the app reopens on the new
version with your save intact. v0.3.0 needs macOS 12 or later. On macOS 11,
v0.2.4 does not offer it; earlier versions do, so decline it there.

## Where your save data lives

| Platform | Path |
|---|---|
| macOS | `~/Library/Application Support/com.swiftiequiz.desktop/save.json` |
| Windows | `%APPDATA%\com.swiftiequiz.desktop\save.json` |

These are the same paths every earlier version used, so your progress,
achievements and settings carry over. Backups (the 3 most recent) live
alongside as `save.backup.<unix-ts>.json`. You can browse and restore them
from the app via **Settings → Backups**.

## Updates

After the first install, the app checks GitHub for new releases on launch
and every 6 hours while running. When an update is available, a badge
appears in the title bar. Click it to view the
release notes and choose to download and install. No update is downloaded
without your explicit consent.

You can disable automatic checks via
**Settings → Updates → Automatically check for updates**.

## Privacy

Update checks send only the app's User-Agent, which names the app and its
version (`SwiftieQuiz/<version>`). No analytics, no install identifiers, no
telemetry.

## Building from source

You need Flutter 3.47.5 (Dart 3.13). macOS builds need a Mac with Xcode;
Windows builds need Windows with Visual Studio's C++ desktop workload and
NSIS 3 for the installer.

```bash
flutter pub get
flutter test

# macOS: Project Swiftie.app, Project Swiftie_<version>_aarch64.dmg and Project Swiftie.app.tar.gz
flutter build macos --release --dart-define=EDITION=open
tool/release/package_macos.sh <version>

# Windows (PowerShell), one edition per build:
# Project Swiftie_<version>_x64-setup.exe (ana) or Project Swiftie Open_<version>_x64-setup.exe (open)
flutter build windows --release --dart-define=EDITION=ana
./tool/release/package_windows.ps1 -Version <version> -Edition ana
```

The packaged files land in `build/release/`. Use the version from
`pubspec.yaml` without its `+build` suffix, and the same edition for the
Flutter build and the installer. A build without `--dart-define=EDITION`
is the Open edition. Builds made this way are not signed for the in-app
updater; only the release workflow signs them.

## Uninstalling

| Platform | How |
|---|---|
| macOS | Drag "Project Swiftie" (or "Swiftie Quiz", if it was updated from there) from Applications to the Trash. To remove save data, also delete `~/Library/Application Support/com.swiftiequiz.desktop`. |
| Windows | Use *Settings → Apps → Installed apps → Project Swiftie → Uninstall*. To remove save data, also delete `%APPDATA%\com.swiftiequiz.desktop`. |

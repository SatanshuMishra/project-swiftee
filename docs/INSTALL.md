# Installation Guide

## System requirements

- **macOS:** 11.0 (Big Sur) or later, Apple Silicon (M1, M2, M3, etc.).
  Intel Macs are not supported.
- **Windows:** 10 build 1809 or later, 64-bit (x86_64).

## Downloading

Visit the [latest release page](https://github.com/SatanshuMishra/project-swiftee/releases/latest)
and download the appropriate file for your OS:

- **macOS:** `Swiftie Quiz_<version>_aarch64.dmg`
- **Windows:** `Swiftie Quiz_<version>_x64-setup.exe`

## First-time install — please read

Swiftie Quiz is **ad-hoc code-signed** but not signed with an Apple Developer
ID and not notarized. This means your operating system will show a one-time
"unidentified developer" warning the first time you launch the app. Once you
allow the launch, every subsequent run is silent. Future in-app updates also
apply silently — the warning only appears for the very first install.

### macOS first-launch walkthrough

1. **Mount the DMG** by double-clicking it. Finder opens the disk image with
   the app icon and an Applications shortcut.
2. **Drag "Swiftie Quiz" to the Applications folder.** If you already have an
   older version, Finder asks whether to replace it — choose **Replace**.
   Your save data is stored separately and is **not** affected.
3. **Open the app from Applications.** macOS blocks the launch with an
   unidentified-developer dialog (the exact wording differs between macOS
   versions, but the buttons are usually **Done** / **Move to Trash** with
   no Open option). Click **Done**.
4. **Open System Settings → Privacy & Security.** Scroll to the Security
   section near the bottom. You'll see a line like:
   *"'Swiftie Quiz' was blocked from use because it is not from an
   identified developer."* Click **Open Anyway** next to it. macOS may ask
   you to authenticate with Touch ID or your password.
5. **Re-launch the app** from Applications. macOS shows one final
   confirmation: *"Are you sure you want to open it?"* — click **Open**.
6. The app launches. From now on, double-clicking the icon opens it normally
   — the dialog will not return.

> **Why is there an extra step?** Swiftie Quiz uses an ad-hoc code signature
> rather than an Apple Developer ID signature ($99/year). Both are
> cryptographically valid, but Apple only auto-trusts apps signed with a
> registered Developer ID. The first launch is the only time you'll see this
> friction; the in-app updater handles all future versions silently.

### Windows first-launch walkthrough

1. **Run the installer** by double-clicking
   `Swiftie Quiz_<version>_x64-setup.exe`.
2. **Microsoft Defender SmartScreen** will show a blue dialog:
   *Microsoft Defender SmartScreen prevented an unrecognized app from starting.*
3. Click the small **More info** link. The dialog expands and shows a
   **Run anyway** button. Click it.
4. The installer runs to completion. The app installs into
   `%LOCALAPPDATA%\Programs\Swiftie Quiz` (no Administrator prompt — per-user
   install).
5. Launch the app from the Start menu. Subsequent launches are silent.

## Where your save data lives

| Platform | Path |
|---|---|
| macOS | `~/Library/Application Support/com.swiftiequiz.desktop/save.json` |
| Windows | `%APPDATA%\com.swiftiequiz.desktop\save.json` |

Backups (the 3 most recent) live alongside as `save.backup.<unix-ts>.json`.
You can browse this folder from the app via **Settings → Backups**.

## Updates

After the first install, the app checks GitHub for new releases on launch
and every 6 hours while running. When an update is available, a badge
appears in the bottom-right corner of the window. Click it to view the
release notes and choose to download and install. No update is downloaded
without your explicit consent.

You can disable automatic checks via
**Settings → Updates → Automatically check for updates**.

## Privacy

Update checks send only your app version, OS, and CPU architecture (the
template substitutions in the manifest URL). No analytics, no install
identifiers, no telemetry.

## Uninstalling

| Platform | How |
|---|---|
| macOS | Drag "Swiftie Quiz" from Applications to the Trash. To remove save data, also delete `~/Library/Application Support/com.swiftiequiz.desktop`. |
| Windows | Use *Settings → Apps → Installed apps → Swiftie Quiz → Uninstall*. To remove save data, also delete `%APPDATA%\com.swiftiequiz.desktop`. |

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

Swiftie Quiz is **not yet code-signed** with Apple Developer ID or Windows
Authenticode. This means your operating system will show a warning the first
time you launch it. The app is safe (you can verify by inspecting the public
source on GitHub), but you do need to click through the warning. After the
first launch, all subsequent updates apply silently — the warning only
appears once.

### macOS first-launch walkthrough

1. **Mount the DMG** by double-clicking it. The Finder will open the disk
   image with the app icon and an Applications shortcut.
2. **Drag "Swiftie Quiz" to the Applications folder.** If you already have
   an older version, the Finder will ask whether to replace it — choose
   **Replace**. Your save data is stored separately and is **not** affected.
3. **Open the app from Applications.** macOS will block the launch with the
   message:
   *"Swiftie Quiz" cannot be opened because the developer cannot be verified.*
4. **Open System Settings → Privacy & Security.** Scroll down. Near
   the bottom you'll see a line that says
   *"Swiftie Quiz" was blocked from use because it is not from an identified developer.*
   Click **Open Anyway** next to it.
5. macOS will show one more confirmation prompt. Click **Open**.
6. The app launches. From now on, double-clicking the icon opens it normally
   — the warning will not return.

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

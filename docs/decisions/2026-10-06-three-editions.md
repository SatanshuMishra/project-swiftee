# Three editions under the Project Swiftie name

Date: 2026-10-06

## Context

The redesign renames Swiftie Quiz to Project Swiftie and splits the app into two editions, chosen at compile time with `--dart-define=EDITION=ana` or `--dart-define=EDITION=open`. The Ana edition is the one made for Ana. The Open edition is for anyone else. A build without the define is the Open edition.

Each version now ships three builds instead of two: macOS Open, Windows Ana and Windows Open. Every copy already installed updates through `latest.json`, the minisign key and the artefact formats, so this record is the release plan that CLAUDE.md rule 2 asks for. It adds one manifest key and changes nothing that an installed copy reads.

## The three artefacts

| Build | Built with | File on the release | Updater artefact |
|---|---|---|---|
| macOS Open | `flutter build macos --release --dart-define=EDITION=open` on macos-26 | `Project.Swiftie_<version>_aarch64.dmg` and `Project.Swiftie.app.tar.gz` | `Project.Swiftie.app.tar.gz`, signed |
| Windows Ana | `flutter build windows --release --dart-define=EDITION=ana` on windows-2025, then `package_windows.ps1 -Edition ana` | `Project.Swiftie_<version>_x64-setup.exe` | the setup executable, signed |
| Windows Open | `flutter build windows --release --dart-define=EDITION=open` on windows-2025, then `package_windows.ps1 -Edition open` | `Project.Swiftie.Open_<version>_x64-setup.exe` | the setup executable, signed |

The packaging scripts write `Project Swiftie_<version>_aarch64.dmg`, `Project Swiftie.app.tar.gz`, `Project Swiftie_<version>_x64-setup.exe` and `Project Swiftie Open_<version>_x64-setup.exe`. GitHub replaces the spaces with dots when they become release assets, so the workflow stages them under the dotted names before uploading, as it did for Swiftie Quiz. The release is named `Project Swiftie <tag>`.

The two Windows builds run as one matrix job, `build-windows`, with one leg per edition. Each leg is signed with the existing Tauri signer step and uploads its own installer, so neither overwrites the other. Build provenance is attested for all three artefacts.

## The five manifest keys

| Key | Points at | Read by |
|---|---|---|
| `darwin-aarch64` | macOS Open archive | Every Flutter macOS copy, v0.3.0 included |
| `darwin-aarch64-app` | macOS Open archive | Tauri-era macOS copies (v0.2.x); the key is kept from the Tauri manifest |
| `windows-x86_64` | Windows Ana installer | Flutter Windows Ana copies, v0.3.0 included |
| `windows-x86_64-nsis` | Windows Ana installer | Tauri-era Windows copies (v0.2.x); the key is kept from the Tauri manifest |
| `windows-x86_64-open` | Windows Open installer | Flutter Windows Open copies, which first ship in this release |

`tool/release/make_manifest.dart` verifies all three signatures against the update key built into the app before it writes `latest.json`. It refuses a missing or unsigned Open installer, and an Open installer that is the Ana installer. The publish check in `release.yml` then refuses the release unless all five keys carry a URL and signature for an asset of this release.

Every later release must keep all five keys. A Windows Open copy that reads a `latest.json` without `windows-x86_64-open` reports "Update issue" until a release with the key is the latest.

## Why Windows stays Ana and macOS becomes Open

Every Windows copy installed today is Ana's: the app was first built for Ana, on Windows. Those copies read `windows-x86_64`, so that key keeps pointing at the Ana build. They update to the Ana edition without any change on their side.

The macOS build was never personal: it is the copy anyone else downloads. It becomes the Open edition and keeps `darwin-aarch64`, so macOS copies update into the Open edition. On first launch after the update, a macOS player without a nickname sees the nickname screen once; the save and records carry over.

The Windows Open edition is new and gets the new key `windows-x86_64-open`. Old copies never read it, so adding it cannot change what they install. `UpdatePlatform.forBuild` in `lib/services/updater/update_config.dart` picks the key from the operating system and the compiled edition.

## Why install identity keeps the old name

Only what people see is renamed: the window and menu-bar name, the installer's name, the version resource, the Start menu and desktop shortcuts, and the entry in Installed apps. What the operating system and the updater use to find an installed copy keeps the old name.

| Kept | Value | Why |
|---|---|---|
| Install folder | `%LOCALAPPDATA%\Swiftie Quiz` | The updater runs the new installer with `/P /UPDATE`, and NSIS reads the folder from the uninstall key. A new folder would install a second copy beside the old one, with two Installed apps entries |
| Uninstall and manufacturer registry keys | `...\Uninstall\Swiftie Quiz`, `Software\swiftiequiz\Swiftie Quiz` | Same lookup; a new key would orphan the old entry |
| Windows executable | `swiftie-quiz.exe` | The installer closes the running app by image name, and existing shortcuts point at this file |
| Bundle identifier | `com.swiftiequiz.desktop` | macOS identifies the installed app by it, and the save folder carries the same name |
| Save folder | `com.swiftiequiz.desktop` under Application Support or `%APPDATA%` | Existing saves must load unchanged (CLAUDE.md rule 1); the app builds this path itself, so the renamed version resource cannot move it |

On macOS the updater unpacks the archive and puts its contents at the installed bundle's own path, dropping the archive's top folder. A copy installed as `/Applications/Swiftie Quiz.app` therefore keeps that folder name after the update, while its menu bar and Dock read Project Swiftie. A fresh install from the DMG is `/Applications/Project Swiftie.app`.

On Windows every install, the silent `/UPDATE` install included, replaces a legacy `Swiftie Quiz.lnk` in the Start menu or on the desktop with `Project Swiftie.lnk`. The install section does this rename before it calls the shortcut functions, which return early in update mode, so updated copies get it too. A fresh install creates only the new names, and uninstalling removes both.

Both Windows editions install to the same folder under the same keys and share one save. One machine runs one edition: installing the other edition replaces the first in place, and its updater then follows the other key.

## Verifying the first release on VMLab

These checks cover criteria 16.18 and 16.55, which no unit test can reach. Run them once the first Project Swiftie release is published.

Windows Ana, updated from v0.3.0:

1. `lab up windows`, then install `Swiftie.Quiz_0.3.0_x64-setup.exe` from the v0.3.0 release and create its desktop shortcut on the finish page.
2. Play one round so `%APPDATA%\com.swiftiequiz.desktop\save.json` holds a record and a changed setting.
3. Wait for the update badge, open it and install. The app closes, updates and reopens.
4. Confirm the app runs from `%LOCALAPPDATA%\Swiftie Quiz\swiftie-quiz.exe` at the new version, and that no `%LOCALAPPDATA%\Project Swiftie` folder exists.
5. Confirm the Start menu and the desktop show Project Swiftie and no Swiftie Quiz shortcut, and that Installed apps lists Project Swiftie once.
6. Confirm the Ana edition opens on the main menu with the record and the setting from step 2.

Windows Open, fresh install:

1. Reset the instance, install `Project.Swiftie.Open_<version>_x64-setup.exe` and launch it.
2. Confirm the custom title bar, the nickname screen on first launch, and **Settings → Updates → Check now** reporting no updates rather than an error.

macOS Open, updated from v0.3.0:

1. `lab up macos`, install v0.3.0 from its DMG into `/Applications/Swiftie Quiz.app`, and play one round.
2. Update through the badge. Confirm the bundle is still `/Applications/Swiftie Quiz.app`, the menu bar reads Project Swiftie, and **Check now** reports no updates.
3. Confirm the nickname screen appears once, then the record from step 1 is on the shelf.

## Rollback

Edit the release back to a draft; `releases/latest` then points at v0.3.0 again. Ana and macOS copies that already updated see v0.3.0 as older and stay where they are. Windows Open copies report "Update issue" until a fixed release is published, because the v0.3.0 `latest.json` has no `windows-x86_64-open` key. Restore `release.yml`, `ci.yml`, `make_manifest.dart`, the packaging scripts and the NSIS script from git to go back to two builds.

# Editions and builds under the Project Swiftie name

Date: 2026-10-06

## Context

The redesign renames Swiftie Quiz to Project Swiftie and splits the app into two editions, chosen at compile time with `--dart-define=EDITION=ana` or `--dart-define=EDITION=open`. The Ana edition is the one made for Ana. The Open edition is for anyone else. A build without the define is the Open edition.

Each version now ships four builds: macOS Ana, macOS Open, Windows Ana and Windows Open. The first Project Swiftie releases shipped three, macOS Open, Windows Ana and Windows Open; the macOS Ana build was added on 2026-10-10, so that a macOS Ana copy updates as Ana instead of turning into the Open edition. Every copy already installed updates through `latest.json`, the minisign key and the artefact formats, so this record is the release plan that CLAUDE.md rule 2 asks for. Each new build adds one manifest key and changes nothing that an installed copy reads.

## The four artefacts

| Build | Built with | File on the release | Updater artefact |
|---|---|---|---|
| macOS Ana | `flutter build macos --release --dart-define=EDITION=ana` on macos-26, then `package_macos.sh <version> ana` | `Project.Swiftie.Ana_<version>_aarch64.dmg` and `Project.Swiftie.Ana.app.tar.gz` | `Project.Swiftie.Ana.app.tar.gz`, signed |
| macOS Open | `flutter build macos --release --dart-define=EDITION=open` on macos-26, then `package_macos.sh <version> open` | `Project.Swiftie_<version>_aarch64.dmg` and `Project.Swiftie.app.tar.gz` | `Project.Swiftie.app.tar.gz`, signed |
| Windows Ana | `flutter build windows --release --dart-define=EDITION=ana` on windows-2025, then `package_windows.ps1 -Edition ana` | `Project.Swiftie_<version>_x64-setup.exe` | the setup executable, signed |
| Windows Open | `flutter build windows --release --dart-define=EDITION=open` on windows-2025, then `package_windows.ps1 -Edition open` | `Project.Swiftie.Open_<version>_x64-setup.exe` | the setup executable, signed |

The packaging scripts write `Project Swiftie Ana_<version>_aarch64.dmg`, `Project Swiftie Ana.app.tar.gz`, `Project Swiftie_<version>_aarch64.dmg`, `Project Swiftie.app.tar.gz`, `Project Swiftie_<version>_x64-setup.exe` and `Project Swiftie Open_<version>_x64-setup.exe`. GitHub replaces the spaces with dots when they become release assets, so the workflow stages them under the dotted names before uploading, as it did for Swiftie Quiz. The release is named `Project Swiftie <tag>`.

The two macOS builds run as one matrix job, `build-macos`, with one leg per edition, and the two Windows builds as another, `build-windows`. Each leg is signed with the existing Tauri signer step and uploads its own files under names no other leg uses, so no leg overwrites another. Build provenance is attested for all four builds: the archive and DMG of each macOS leg and the installer of each Windows leg.

## The six manifest keys

| Key | Points at | Read by |
|---|---|---|
| `darwin-aarch64` | macOS Open archive | Flutter macOS Open copies, v0.3.0 included, and macOS Ana copies built before `darwin-aarch64-ana` existed (the maintainer's local 0.5.4 copy) |
| `darwin-aarch64-app` | macOS Open archive | Tauri-era macOS copies (v0.2.x); the key is kept from the Tauri manifest |
| `darwin-aarch64-ana` | macOS Ana archive | macOS Ana copies built from the release that adds it onward |
| `windows-x86_64` | Windows Ana installer | Flutter Windows Ana copies, v0.3.0 included |
| `windows-x86_64-nsis` | Windows Ana installer | Tauri-era Windows copies (v0.2.x); the key is kept from the Tauri manifest |
| `windows-x86_64-open` | Windows Open installer | Flutter Windows Open copies, which first ship in this release |

`tool/release/make_manifest.dart` verifies all four signatures against the update key built into the app before it writes `latest.json`. It also refuses any artefact not named as expected for its key: `darwin-aarch64` and `darwin-aarch64-app` need `Project.Swiftie.app.tar.gz`, `darwin-aarch64-ana` needs `Project.Swiftie.Ana.app.tar.gz`, `windows-x86_64` and `windows-x86_64-nsis` need `Project.Swiftie_<version>_x64-setup.exe`, and `windows-x86_64-open` needs `Project.Swiftie.Open_<version>_x64-setup.exe`. This stops a swapped or mislabelled artefact before `latest.json` is written. It refuses a missing or unsigned Open installer, and an Open installer that is the Ana installer. It refuses a missing or unsigned macOS Ana archive the same way, and a macOS Ana archive that is the Open archive. The publish check in `release.yml` then refuses the release unless all six keys carry a URL and signature for an asset of this release.

Once any macOS Ana copy has been installed from a release carrying `darwin-aarch64-ana`, every later release must keep all six keys. A Windows Open copy that reads a `latest.json` without `windows-x86_64-open` reports "Update issue" until a release with the key is the latest, and so does a macOS Ana copy that reads one without `darwin-aarch64-ana`.

## Why Windows stays Ana and macOS becomes Open

Every Windows copy installed today is Ana's: the app was first built for Ana, on Windows. Those copies read `windows-x86_64`, so that key keeps pointing at the Ana build. They update to the Ana edition without any change on their side.

The macOS build was never personal: it is the copy anyone else downloads. It becomes the Open edition and keeps `darwin-aarch64`, so macOS copies update into the Open edition. On first launch after the update, a macOS player without a nickname sees the nickname screen once; the save and records carry over. The macOS Ana edition came later, as a second app with its own key, described below.

The Windows Open edition is new and gets the new key `windows-x86_64-open`. Old copies never read it, so adding it cannot change what they install. `UpdatePlatform.forBuild` in `lib/services/updater/update_config.dart` picks the key from the operating system and the compiled edition.

## The macOS Ana edition

The macOS build that everyone else downloads stays the Open edition. The macOS Ana edition is a second app, and it installs beside the Open app.

| | macOS Ana | macOS Open |
|---|---|---|
| Display and bundle name | Project Swiftie Ana | Project Swiftie |
| Bundle identifier | `com.swiftiequiz.desktop.ana` | `com.swiftiequiz.desktop` |
| Executable file | `Project Swiftie` | `Project Swiftie` |
| Save folder | `com.swiftiequiz.desktop` | `com.swiftiequiz.desktop` |
| Caches and preferences | under `com.swiftiequiz.desktop.ana` | under `com.swiftiequiz.desktop` |
| Fresh install | `/Applications/Project Swiftie Ana.app` | `/Applications/Project Swiftie.app` |
| Manifest key | `darwin-aarch64-ana` | `darwin-aarch64` |

The save is shared because the app builds its save path from the home folder and the fixed name `com.swiftiequiz.desktop` (`lib/data/save/save_location.dart`), never from the bundle identifier. What macOS keys by bundle identifier, such as caches and preferences, lives under `com.swiftiequiz.desktop.ana`, apart from the Open app's.

Do not run both macOS editions at the same time. Each writes its whole progress when it saves, so the one that saves last overwrites the other's changes, such as a new nickname or server link.

### Why the identity is applied when packaging

The release builds the normal Runner target with `--dart-define=EDITION=ana`. `tool/release/package_macos.sh <version> ana` then copies the built `Project Swiftie.app` to `Project Swiftie Ana.app`, sets `CFBundleIdentifier`, `CFBundleName` and `CFBundleDisplayName` with PlistBuddy, signs the copy ad hoc and verifies it with `codesign --verify --deep --strict` before it writes the DMG and the archive. `package_macos.sh <version> open` packages the built app under its own name, as the script always did.

The identity cannot be set at build time. `FLUTTER_XCODE_PRODUCT_NAME` and `FLUTTER_XCODE_PRODUCT_BUNDLE_IDENTIFIER` apply to every target, so they rename the Swift Package Manager plugin targets too, and the build fails with duplicate output files. That is also why the executable keeps the file name `Project Swiftie`: renaming it needs the product name, and nothing reads it.

The updater drops the archive's top folder and puts the contents at the installed bundle's own path, so the folder name inside `Project.Swiftie.Ana.app.tar.gz` never affects updates.

### Moving the existing local Ana copy

The one macOS Ana copy that existed before this change is a local 0.5.4 build on the maintainer's Mac, and it reads `darwin-aarch64`, which points at the Open archive. Never accept its in-app update: it would replace the app with the Open edition.

Once a release carries `darwin-aarch64-ana`, install that release's Ana DMG over `/Applications/Project Swiftie Ana.app`. It has the same name, the same bundle identifier and the same save, so it replaces the local copy in place, and from then on the copy reads `darwin-aarch64-ana`. If the local copy already updated into the Open edition, the same install restores Ana.

## Why install identity keeps the old name

Only what people see is renamed: the window and menu-bar name, the installer's name, the version resource, the Start menu and desktop shortcuts, and the entry in Installed apps. What the operating system and the updater use to find an installed copy keeps the old name.

| Kept | Value | Why |
|---|---|---|
| Install folder | `%LOCALAPPDATA%\Swiftie Quiz` | The updater runs the new installer with `/P /UPDATE`, and NSIS reads the folder from the uninstall key. A new folder would install a second copy beside the old one, with two Installed apps entries |
| Uninstall and manufacturer registry keys | `...\Uninstall\Swiftie Quiz`, `Software\swiftiequiz\Swiftie Quiz` | Same lookup; a new key would orphan the old entry |
| Windows executable | `swiftie-quiz.exe` | The installer closes the running app by image name, and existing shortcuts point at this file |
| Bundle identifier of the macOS Open edition | `com.swiftiequiz.desktop` | macOS identifies the installed app by it, and the save folder carries the same name. macOS Ana uses `com.swiftiequiz.desktop.ana`, because no released macOS Ana copy existed whose identity had to be kept; its save folder stays `com.swiftiequiz.desktop` |
| Save folder | `com.swiftiequiz.desktop` under Application Support or `%APPDATA%`, for every edition | Existing saves must load unchanged (CLAUDE.md rule 1); the app builds this path itself, so the renamed version resource cannot move it |

On macOS the updater unpacks the archive and puts its contents at the installed bundle's own path, dropping the archive's top folder. A copy installed as `/Applications/Swiftie Quiz.app` therefore keeps that folder name after the update, while its menu bar and Dock read Project Swiftie. A fresh install from the Open DMG is `/Applications/Project Swiftie.app`, and from the Ana DMG `/Applications/Project Swiftie Ana.app`.

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

## Verifying macOS Ana on VMLab

No unit test can install a published release and update it, so these checks cover the macOS Ana build.

First release that carries `darwin-aarch64-ana`:

1. `lab up macos`, then install both macOS DMGs from the release, `Project.Swiftie.Ana_<version>_aarch64.dmg` and `Project.Swiftie_<version>_aarch64.dmg`, so `/Applications` holds `Project Swiftie Ana.app` and `Project Swiftie.app` side by side.
2. Open each one. Both open, and Project Swiftie Ana shows no nickname screen.
3. In each, **Settings → Updates → Check now** reports no update.

Second release that carries the key:

1. `lab up macos`, install the Ana DMG from the first release that carries the key, open it and play one round.
2. Wait for the update badge, open it and install. The app closes, updates and reopens.
3. Confirm it reopens as Project Swiftie Ana at `/Applications/Project Swiftie Ana.app`, with bundle identifier `com.swiftiequiz.desktop.ana`, no nickname screen and the record from step 1.

## Rollback

Edit the release back to a draft; `releases/latest` then points at v0.3.0 again. Ana and macOS copies that already updated see v0.3.0 as older and stay where they are. Windows Open copies report "Update issue" until a fixed release is published, because the v0.3.0 `latest.json` has no `windows-x86_64-open` key. Restore `release.yml`, `ci.yml`, `make_manifest.dart`, the packaging scripts and the NSIS script from git to go back to two builds.

Pulling the first release with `darwin-aarch64-ana` back to a draft works the same way. The release before it becomes the latest, and its `latest.json` has no `darwin-aarch64-ana` key, so macOS Ana copies installed from the pulled release report "Update issue" until a release with the key is the latest. Every other copy sees an older version and stays where it is. Going back to three builds by restoring `release.yml`, `ci.yml`, `make_manifest.dart`, `package_macos.sh` and `update_config.dart` from git is possible only if no macOS Ana copy was installed from the pulled release. Once one was, every later release keeps building the macOS Ana edition and publishing `darwin-aarch64-ana`, and a broken Ana build is fixed in the next release. Dropping the key would strand those copies, which would then have to be removed by hand and replaced with the Open DMG.

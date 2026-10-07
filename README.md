# Project Swiftie

A Taylor Swift trivia game for macOS and Windows, built with Flutter.
Choose your album, answer questions about songs and lyrics, unlock
cat-themed achievements, climb your high-score streak. Formerly
Swiftie Quiz.

It comes in two editions: the Ana edition, made for Ana, and the Open
edition for everyone else. Each release ships three builds: macOS
(Open), Windows Ana and Windows Open.

This is a personal/hobby project. Distribution is unsigned for now —
the in-app updater is the update channel from v0.2.0 onward.

## System requirements

- **macOS** 12 (Monterey) or later, **Apple Silicon** (M1+)
- **Windows** 10 or 11, **x64**

Intel Macs and Linux are not supported. macOS 11 is no longer supported
from v0.3.0, because Flutter requires macOS 12.

## Installing

Download the latest version from the
[latest release page](https://github.com/SatanshuMishra/project-swiftee/releases/latest):

| Build | File |
|---|---|
| macOS (Open edition) | `Project.Swiftie_<version>_aarch64.dmg` |
| Windows, Ana edition | `Project.Swiftie_<version>_x64-setup.exe` |
| Windows, Open edition | `Project.Swiftie.Open_<version>_x64-setup.exe` |

Install one Windows edition per machine; both use the same folder and
save, so installing the other edition replaces the first in place.

See [docs/INSTALL.md](docs/INSTALL.md) for first-time install
instructions, including how to handle the macOS Gatekeeper and
Windows SmartScreen warnings for unsigned apps. The first install
needs a one-time click-through; subsequent updates apply without
warnings.

## Updates

After installation, the app checks GitHub Releases for new versions
on launch and every 6 hours while running. New versions appear as a
small badge in the title bar — click to read release notes and
explicitly consent to download and install. No silent downloads.

Update checks send only the app's User-Agent, which names the app
and its version (`SwiftieQuiz/<version>`). **No analytics, no install
identifiers, no telemetry.**
You can disable automatic checks via **Settings → Updates**.

Updates are cryptographically verified with a minisign signature
before installation. Copies installed before the Flutter rewrite
update to it through their own updater, and your save carries over.
Swiftie Quiz copies update to Project Swiftie the same way: Windows
copies become the Ana edition and macOS copies the Open edition, in
their existing install folder (see
[the three-editions decision](docs/decisions/2026-10-06-three-editions.md)).

## Development

Flutter 3.47.5 (Dart 3.13), Riverpod 3, flutter_soloud for audio.
Public APIs only (Deezer, LRCLIB) — no auth, no PII.

```bash
# install dependencies
flutter pub get

# run the desktop app (recommended for visual verification)
flutter run -d macos

# tests
flutter test

# analyze + format check
flutter analyze --fatal-infos
dart format --output=none --set-exit-if-changed lib test tool

# run a chosen edition (ana or open; without the define it is open)
flutter run -d macos --dart-define=EDITION=ana

# build and package for macOS (on a Mac): Project Swiftie_<version>_aarch64.dmg + Project Swiftie.app.tar.gz
flutter build macos --release --dart-define=EDITION=open
tool/release/package_macos.sh 0.3.0

# build and package for Windows (on Windows, with NSIS 3), one edition per build:
# Project Swiftie_<version>_x64-setup.exe (ana) or Project Swiftie Open_<version>_x64-setup.exe (open)
flutter build windows --release --dart-define=EDITION=ana
./tool/release/package_windows.ps1 -Version 0.3.0 -Edition ana
```

Packaged files land in `build/release/`. Releases are built by the
`v*` tag workflow in `.github/workflows/release.yml`, which signs the
updater artifacts and writes `latest.json`.

## Project layout

| Path | What |
|---|---|
| `lib/domain/` | Pure game rules and models (no Flutter, no IO) |
| `lib/data/` | Deezer and LRCLIB clients, save-file IO + migrations + backups |
| `lib/services/` | Audio (flutter_soloud) and the updater |
| `lib/state/` | Riverpod controllers |
| `lib/ui/`, `lib/app/` | Screens, widgets, theme, app shell |
| `assets/` | Cat icon, brand icon, bundled catalogue, quack sound |
| `test/` | flutter_test unit and widget tests |
| `installer/windows/` | NSIS installer script |
| `tool/release/` | Packaging scripts, release checks, `latest.json` writer |
| `docs/decisions/` | Decision records |
| `docs/INSTALL.md` | User-facing install guide |
| `CHANGELOG.md` | Release notes (source of `latest.json` notes via CI) |

## License

Licensed under the Apache License, Version 2.0; see [LICENSE](LICENSE). The license covers the whole history of this repository, from its first commit, including the period it carried the MIT License. The quack sound effect keeps its own license; [NOTICE](NOTICE) lists it.

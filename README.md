# Swiftie Quiz

A Taylor Swift trivia game for macOS and Windows, built with Flutter.
Choose your album, answer questions about songs and lyrics, unlock
cat-themed achievements, climb your high-score streak.

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
`Swiftie Quiz_<version>_aarch64.dmg` for macOS or
`Swiftie Quiz_<version>_x64-setup.exe` for Windows.

See [docs/INSTALL.md](docs/INSTALL.md) for first-time install
instructions, including how to handle the macOS Gatekeeper and
Windows SmartScreen warnings for unsigned apps. The first install
needs a one-time click-through; subsequent updates apply without
warnings.

## Updates

After installation, the app checks GitHub Releases for new versions
on launch and every 6 hours while running. New versions appear as a
small badge in the window — click to read release notes and
explicitly consent to download and install. No silent downloads.

Update checks send only the app's User-Agent, which names the app
and its version (`SwiftieQuiz/<version>`). **No analytics, no install
identifiers, no telemetry.**
You can disable automatic checks via **Settings → Updates**.

Updates are cryptographically verified with a minisign signature
before installation. Copies installed before the Flutter rewrite
update to it through their own updater, and your save carries over.

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

# build and package for macOS (on a Mac): Swiftie Quiz_<version>_aarch64.dmg + Swiftie Quiz.app.tar.gz
flutter build macos --release
tool/release/package_macos.sh 0.3.0

# build and package for Windows (on Windows, with NSIS 3): Swiftie Quiz_<version>_x64-setup.exe
flutter build windows --release
./tool/release/package_windows.ps1 -Version 0.3.0
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
| `assets/` | Cat icon, achievement cats, icons, quack sound |
| `test/` | flutter_test unit and widget tests |
| `installer/windows/` | NSIS installer script |
| `tool/release/` | Packaging scripts, release checks, `latest.json` writer |
| `docs/decisions/` | Decision records |
| `docs/INSTALL.md` | User-facing install guide |
| `CHANGELOG.md` | Release notes (source of `latest.json` notes via CI) |

## License

Licensed under the Apache License, Version 2.0; see [LICENSE](LICENSE). The license covers the whole history of this repository, from its first commit, including the period it carried the MIT License. The quack sound effect keeps its own license; [NOTICE](NOTICE) lists it.

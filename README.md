# Swiftie Quiz

A Taylor Swift trivia game built with Tauri 2 (Rust + React/TypeScript).
Choose your album, answer questions about songs and lyrics, unlock
cat-themed achievements, climb your high-score streak.

This is a personal/hobby project. Distribution is unsigned for now —
the in-app updater will be the long-term update channel from v0.2.0
onward.

## System requirements

- **macOS** 11.0 (Big Sur) or later, **Apple Silicon** (M1+)
- **Windows** 10 build 1809 or later, **x86_64**

Intel Macs and Linux are not supported in v0.2.0. Linux support has
no current plans; Intel Mac support is documented as a low-cost
future expansion (see [docs/superpowers/specs/2026-04-30-auto-update-system-design.md](docs/superpowers/specs/2026-04-30-auto-update-system-design.md)).

## Installing

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

Update checks send only your app version, OS, and CPU architecture.
**No analytics, no install identifiers, no telemetry.** You can
disable automatic checks via **Settings → Updates**.

Updates are cryptographically verified before installation. See
the [auto-update design spec](docs/superpowers/specs/2026-04-30-auto-update-system-design.md)
for the full security and privacy posture.

## Development

Tauri 2 + React 18 + TypeScript strict + Rust 2021. Public APIs
only (Deezer, LRCLIB) — no auth, no PII.

```bash
# install deps
npm install

# dev mode (web only)
npm run dev

# dev mode (full desktop, recommended for visual verification)
npm run tauri dev

# tests
npm test
cd src-tauri && cargo test

# lint + typecheck
npm run lint
npx tsc --noEmit
cd src-tauri && cargo clippy -- -D warnings

# build
npm run build
npm run tauri build
```

## Project layout

| Path | What |
|---|---|
| `src/` | React frontend (TS strict, Zustand, Tailwind v4, Vite 6) |
| `src/engine/` | Pure game logic (no React/DOM) |
| `src/hooks/` | Side effects (audio, IPC, persistence) |
| `src-tauri/src/` | Rust backend (commands, models, services, storage) |
| `src-tauri/src/storage/` | Save-file IO + migrations + backups |
| `docs/superpowers/specs/` | Design specs |
| `docs/superpowers/plans/` | Implementation plans |
| `docs/INSTALL.md` | User-facing install guide |
| `CHANGELOG.md` | Release notes (source of `latest.json` notes via CI) |

## License

(No license declared yet — repository is currently a personal
distribution.)

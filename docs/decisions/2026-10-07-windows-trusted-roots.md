# Trusted roots on Windows

Date: 2026-10-07

## Context

Lyrics games on Windows failed with "Not enough songs with lyrics available" while the same build worked on macOS. Every LRCLIB request failed its TLS handshake, and the lyrics client counted each failure as a song without lyrics.

Dart on Windows does not ask Windows whether a certificate is trusted. When the first TLS connection opens, it copies the certificates already in the Windows root store into its own TLS library and checks every connection against that copy, once per process. Windows ships with a small root store and adds other roots only when its own networking first needs them, through Automatic Root Certificates Update. Dart never triggers that.

A fresh Windows 11 install holds 19 roots. Deezer (DigiCert Global Root G2) and GitHub (USERTrust ECC, ISRG Root X1) chain to roots it holds. LRCLIB chains to GTS Root R4, which it does not hold, and neither does the GlobalSign Root CA that cross-signs it. A VMLab run on 2026-10-07 confirmed it with the shipped v0.4.1: the lyrics game failed; after Windows' own networking fetched LRCLIB once and added GlobalSign Root CA to the store, the same app worked after a restart. The running app kept failing until it restarted, because Dart reads the store once per process.

The relay a player adds in Settings depends on the same luck: whether a host works depends on which root its certificate provider uses that month.

## Decision

**On Windows the app also trusts Mozilla's root set.** `assets/certs/cacert.pem` is the bundle curl publishes from Mozilla's root store (https://curl.se/docs/caextract.html), checked against its published SHA-256 when added. At startup, `trustBundledRootsOnWindows` installs `BundledRootsOverrides` as the process-wide `HttpOverrides`, so every `HttpClient` the app creates (the `http` client, the relay's WebSocket, album covers) checks certificates against the Windows store plus the bundle. Certificates are still fully verified; the set of trusted roots grows to the one Firefox and curl use.

macOS is unchanged: Dart verifies there through the system's own trust evaluation, which fetches what it needs.

A test pins that the bundle holds the roots behind LRCLIB, Deezer, GitHub and the relay, and another checks with a local HTTPS server that a client trusts a bundled root only through the override.

## Refreshing the bundle

Replace `assets/certs/cacert.pem` with the current file from https://curl.se/ca/cacert.pem and check it against https://curl.se/ca/cacert.pem.sha256. Doing it once or twice a year keeps up with Mozilla's additions and removals; roots change slowly, and the Windows store still applies alongside it.

## Not decided here

The app does not ask Windows to verify certificates itself, which would need calls into Windows' certificate API and would still depend on Windows Update being reachable.

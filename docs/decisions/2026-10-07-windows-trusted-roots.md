# Trusted roots on Windows

Date: 2026-10-07

## Context

Lyrics games on Windows failed with "Not enough songs with lyrics available" while the same build worked on macOS. Every LRCLIB request failed its TLS handshake, and the lyrics client counted each failure as a song without lyrics.

Dart on Windows does not ask Windows whether a certificate is trusted. When the first TLS connection opens, it copies the certificates already in the Windows root store into its own TLS library and checks every connection against that copy, once per process. Windows ships with a small root store and adds other roots only when its own networking first needs them, through Automatic Root Certificates Update. Dart never triggers that.

A fresh Windows 11 install holds 19 roots. Deezer's API and clip CDN (DigiCert Global Root G2) and GitHub (USERTrust ECC, ISRG Root X1) chain to roots it holds. LRCLIB chains to GTS Root R4, which it does not hold, and neither does the GlobalSign Root CA that cross-signs it. Deezer's cover CDN chains to Starfield Root Certificate Authority - G2, which it does not hold either, so album covers fell back to their placeholders. A VMLab run on 2026-10-07 confirmed it with the shipped v0.4.1: the lyrics game failed; after Windows' own networking fetched LRCLIB once and added GlobalSign Root CA to the store, the same app worked after a restart. The running app kept failing until it restarted, because Dart reads the store once per process.

The relay a player adds in Settings depends on the same luck: whether a host works depends on which root its certificate provider uses that month.

## Decision

**On Windows the app also trusts Mozilla's root set.** `assets/certs/cacert.pem` is the bundle curl publishes from Mozilla's root store (https://curl.se/docs/caextract.html), checked against its published SHA-256 when added. At startup, `trustBundledRootsOnWindows` installs `BundledRootsOverrides` as the process-wide `HttpOverrides`, so every `HttpClient` the app creates (the `http` client, the relay's WebSocket, album covers) checks certificates against the Windows store plus the bundle. Certificates are still fully verified; the set of trusted roots grows to the one Firefox and curl use.

macOS is unchanged: Dart verifies there through the system's own trust evaluation, which fetches what it needs.

If the bundle cannot be read or parsed, the app logs it and keeps Windows' own store, so it still starts and still verifies every certificate.

Tests pin the bundle's SHA-256 and that it holds the roots behind LRCLIB, Deezer, its covers, GitHub and the relay. Against local HTTPS servers they check that a client trusts a bundled root only through the override, still refuses a root outside the bundle and a certificate for another host name, and that a client given its own security context keeps it. CI runs these tests on the Windows runner too, where Dart's Windows trust code is the one under test.

## Refreshing the bundle

Replace `assets/certs/cacert.pem` with the current file from https://curl.se/ca/cacert.pem, check it against https://curl.se/ca/cacert.pem.sha256, and put the new hash in `_bundledRootsSha256` in `test/services/network/bundled_roots_test.dart`. `.gitattributes` keeps git from converting the file's line endings, so a Windows checkout ships the same bytes curl published. The release check (`tool/release/check_release.dart`) refuses to release a bundle taken from Mozilla more than 180 days earlier, so a refresh happens at least twice a year and Mozilla's removals reach players.

## Accepted risks

The bundle is plain PEM, so it cannot carry what Firefox applies on top of Mozilla's list: name constraints on some roots, distrust-after dates, and revoked intermediates (OneCRL). A root that a user or an administrator removed from the Windows store is trusted again through the bundle. The app talks to a handful of fixed hosts plus one relay the player chooses, verifies every host name, and refreshes the bundle at least every 180 days, so these stay accepted.

## Not decided here

The app does not ask Windows to verify certificates itself, which would need calls into Windows' certificate API and would still depend on Windows Update being reachable.

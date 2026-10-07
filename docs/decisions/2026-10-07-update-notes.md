# Readable update notes

Date: 2026-10-07

## Context

The release workflow published each version's CHANGELOG section, which is Markdown, as the `notes` value in `latest.json`, and the update window showed it in a plain text widget. Players saw `###` headings and `**` markers. The notes are always shown by the version being replaced, so a renderer added to the app only helps from the version after it ships: v0.4.0 and v0.4.1 will show whatever `latest.json` carries for as long as they run.

## Decision

**`latest.json` carries plain text.** `tool/release/make_manifest.dart` turns the CHANGELOG section into plain text with `plainReleaseNotes` (`lib/domain/engine/release_notes.dart`): each heading on its own line after a blank line, bullets marked with "• ", and bold, code and link markup reduced to their text. The key and its type do not change, so the updater protocol is untouched, and every installed copy reads clean notes from the next release on. The GitHub release page keeps the Markdown.

**The update window shows the structure.** `parseReleaseNotes` reads either Markdown or that plain text into headings, bullets and paragraphs, and the window draws headings as section labels announced as headers and bullets with a hanging indent. A test checks that every CHANGELOG section reads the same from its plain notes as from its Markdown.

In plain text, a heading is a line directly above other text, and paragraphs are single lines; plain text is recognised by its "• " bullets.

## Not decided here

`latest.json` carries only the newest section, so a copy that skips versions, such as v0.3.0 offered v0.4.1, never sees the skipped versions' "Updating from" notes.

# Readable update notes

Date: 2026-10-07

## Context

The release workflow published each version's CHANGELOG section, which is Markdown, as the `notes` value in `latest.json`, and the update window showed it in a plain text widget. Players saw `###` headings and `**` markers. The notes are always shown by the version being replaced, so a renderer added to the app only helps from the version after it ships: v0.4.0 and v0.4.1 will show whatever `latest.json` carries for as long as they run, and the reader added here will read every later `latest.json` for as long as its copies run.

## Decision

**`latest.json` carries plain text.** `tool/release/make_manifest.dart` turns the CHANGELOG section into plain text with `plainReleaseNotes` (`lib/domain/engine/release_notes.dart`). The key and its type do not change, so the updater protocol is untouched, and every installed copy reads clean notes from the next release on. The GitHub release page keeps the Markdown.

**The plain format is a contract.** Old copies show it as typed, and the update window reads it back:

- Blocks are separated by one blank line, except that whatever sits directly under a heading follows it on the next line, and consecutive list items follow each other.
- A line that is not a list item is a heading when another line follows it before the next blank line, and a paragraph otherwise. Paragraphs are always one line.
- A list item is "• " or a number with "." or ")" and a space; two spaces of indent per level of nesting.
- Text is shown as written: bold, emphasis, link and image markup is removed when the plain text is made, and code spans keep their content exactly.
- A heading with nothing after it at the end of the section is left out.

A test turns fifteen note shapes and every CHANGELOG section into plain text and checks that each reads back as the same blocks as its Markdown.

**The update window shows the structure.** `parseReleaseNotes` reads plain text, or Markdown when a line starts with `#` or a `-`, `*` or `+` bullet, into headings, list items and paragraphs. The window draws headings as section labels announced as headers, and list items with a hanging marker column that grows with the text size and an indent per nesting level. The bullet dot is hidden from screen readers; a step is read with its number.

Lists are not announced as lists: Flutter's macOS and Windows accessibility bridge sets roles from semantics flags only, so `SemanticsRole.list` would not reach VoiceOver or Narrator.

## Not decided here

`latest.json` carries only the newest section, so a copy that skips versions, such as v0.3.0 offered v0.4.1, never sees the skipped versions' "Updating from" notes.

At twice the normal text size the update window's buttons and panel overflow; that is the window's layout, not the notes.

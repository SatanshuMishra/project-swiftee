# A saved server link shows as stars

Date: 2026-10-08

## Context

The Play together server link in Settings stayed in plain text after it was saved. Anyone looking at the screen, or sharing it, could read the server key, and a stray keystroke in the field could change or delete the link.

## Decision

**The link is visible only while it is being typed or pasted.** When the field loses focus with a valid link saved, the link is drawn as one `*` per character and the field is disabled: it cannot take focus, be selected, copied or edited, and screen readers hear the stars rather than the link. The status line under it, such as "Connected to swiftie.satanshu.tech.", still shows.

**Clear is the only way to change a saved link.** It sits inside the field's underline, the same text link the album search uses, and one press empties the field, removes the saved link and puts the cursor in the field for a new one. There is no confirmation dialog: the lock is the guard against an accidental change, and Clear is a deliberate press on a separate control.

Anything that takes focus from the field locks it, including switching to another app, because Flutter suspends focus while the window is inactive. An invalid link left in the field is still dropped when focus leaves, and the field stays open. A saved value that is not a link, which only a hand-edited save can hold, leaves the field open too.

The text field is rebuilt each time it locks or unlocks. That starts the stars at the left edge however the link was entered, and it discards the field's undo history, so pressing undo after Clear cannot bring back a link pasted earlier.

## Limits

This hides the link from the screen, the clipboard and the accessibility tree. It does not protect the key at rest: save.json keeps `togetherLink` in plain text, as the Tauri-era save format requires, so anyone who can read the app data folder can read the link.

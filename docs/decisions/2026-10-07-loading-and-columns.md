# One loader per wait, and when a column is centred

Date: 2026-10-07

## Context

A Sound game showed two different waits. Round one opened at once and loaded its clip on the play button, with the four answers already clickable, so a player could answer before hearing anything while the timer had not started. Every later round covered the screen with the cat loader ("Loading next track...") for at least 450 ms, as the redesign handoff specifies between songs. The difference came from round one starting with `immediate: true` in `lib/ui/screens/game_screen.dart`.

The two-pane screens also differ in alignment: the main menu centres its right column, while Set up and Settings keep theirs at the top. Asked whether every two-pane screen should centre, we kept the difference and wrote down the rule.

## Decision

**A full-page cat loader covers every wait before a round can be played; the play button shows only waits inside a round.** Round one now stays on the "Loading tracks..." page, with its Back to menu link, until its clip is ready, so one loader runs from Start until the first clip plays. Rounds after it keep the "Loading next track..." cover. Both wait at least 450 ms and give up after 8 s, showing the round with the play button still loading. The play button's loading state remains for replays inside a round. Lyrics games already worked this way: their loading page comes first and rounds then appear at once.

**A column is centred only when it is a short, fixed set of places to go.** The main menu's right column and the round summary centre. A column that is a form or a list, whose height changes while it is used or can scroll, stays at the top: Set up and Settings. Centred, Set up's controls would jump under the pointer whenever a section appeared or disappeared, as choosing Lyrics or picking an era without re-recordings does, and Settings is taller than a 1024 by 768 window, so centring would apply only on large screens. This matches the redesign mock-up, which centres only the menu's right column.

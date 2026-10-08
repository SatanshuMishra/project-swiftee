# One way out of a Play together game

Date: 2026-10-07

## Context

The final standings gave the host "Play again →" and "Back to menu", and gave guests "Back to menu" only. Play again sent everyone back to the room at once, even a guest still reading the results. The host's Back to menu closed the room for everybody, so a host who only meant to leave the screen ended the evening for the whole group. A guest's Back to menu left the room, so playing another game meant joining with the code again.

## Decision

**Every player sees one button, "Next →", and it takes that player back to the room.** Nobody else moves when one player presses it, so each person reads the results at their own pace. The host's Next also reopens the room, so friends can join and the host can change the game before starting again. A guest still on the results when the host starts the next game goes straight to its countdown, as before.

**Leaving happens from the room.** The room already offers "Leave room" to guests and "Close room" to the host, each with a confirmation, so the end of a game no longer has a way to leave by accident.

If the host closes the room while a guest is still on the results, the guest's Next shows the room's existing "the host closed the room" page with its way back to the menu.

The host no longer sends BackToLobby at the end of a game. The message remains for a start that fails, which still returns everyone to the room.

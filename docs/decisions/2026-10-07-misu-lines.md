# What Misu says, and how long he stays

Date: 2026-10-07

## Context

Misu had one line for each moment, so a regular player heard the same greeting every morning and the same remark after every streak. His bubble left after 4.2 seconds whether or not anyone was looking, so a player who glanced away, switched apps or had a dialog open missed it. He never noticed when a player wandered off.

## Decision

**Every moment has four versions, and the away line has six.** The lines were written with the maintainer to one voice: Misu is a smart, sassy gremlin who loves food, treats and zoomies and leaves fur wherever he rolls. In the Ana edition he talks as "I" and names Ana in about one line in five, never as a reflex. In the Open edition he talks about himself as Misu and uses the nickname sparingly. Lines that comfort, reassure or explain themselves were left out on purpose. Ana's coffee appears only in the Ana edition.

**The greeting changes with the calendar day; everything else works through its versions.** The greeting's version comes from the date, so consecutive days never repeat and no save change is needed. Every other line plays each version once, in random order, before any repeats, and never says the same thing twice in a row. That memory lasts for the session.

**After five minutes with no mouse, trackpad or key input in the app, Misu drops in once.** Time spent in another app counts as away. He stays quiet when visits are off, on the first-launch nickname screen, while a Play together game is running, and while he is already talking. He drops in again only after the player has come back and left again.

**A line stays for 8 seconds, 12 for the introduction, counted only while the player can see it.** The countdown runs while the window is focused, the player has used the mouse or keyboard in the last 30 seconds, and no dialog covers Misu. When any of those stops, the countdown stops; when they all hold again, the full 8 seconds start over, so a returning player always gets a full read. The away line therefore waits for the player to come back.

Input and window focus are watched only while the app shell is on screen. Without that listener nothing can report input, so idle time is not counted.

The Misu visits setting keeps its three choices. Its note now calls Misu "he", matching how the maintainer talks about him. His bubble keeps whole words at large text sizes by drawing a word too long for it slightly smaller, the same way headings do.

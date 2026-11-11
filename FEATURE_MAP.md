# Feature map

The repo is https://github.com/sophomorica/scripture-up. Scripture Up 1.2.0+5. Portrait lobby, landscape round. Bundle id `com.narrowroad.scriptureup`. Team `JQ7J89B22A`.

## Screens

| Screen | Where | Orientation | Notes |
| --- | --- | --- | --- |
| Lobby | `LobbyScreen` | Portrait | Deck-first. The picker is ALL, OT, NT, BOM, and D&C. Book of Mormon is the default. A canon tile selects that same book. Party tiles say COMING SOON, are hatched, and open a sheet with PLAY disabled that points at the book picker. |
| Deck sheet | `DeckSheet` | Portrait | Length, Record the team (off), Tilt or Tap buttons. |
| About | `AboutSheet` | Portrait | How to play, silent-switch preference (applies at once), affiliation line. Long-press the title for the tilt debug line. |
| Forehead | `ForeheadView` | Landscape | `ROUND N`. One line for the guesser: name the book, chapter, and verse. Level hold arms the countdown, or START in tap mode. The close control leaves to the lobby. |
| Countdown | `CountdownView` | Landscape | 3, 2, 1 at 900 ms. The team's job on the left (read the phrase, give any hints) and NEVER SAY (book, chapter, verse) on the right. The ring sweeps once per beat and the numeral lands from 1.3x to 1x. Flat phone cancels back to forehead. |
| Card | `CardPlayView` | Landscape | Full-bleed deck color. The phrase is the hero, auto-fit from 44 pt down, exactly as written. A gold ANSWER line carries the reference. Drawn tilt hints, or PASS and GOT IT. Ember edge glow in the last 10 s. |
| Correct / pass | flash views | Landscape | Gold got-it with a pop, a turning full-circle sunburst, and outward confetti. Amethyst pass that holds, then slides up and fades. Both run from the controller's flash progress. Reduce motion shows one still frame. Timer keeps running. |
| Time's up | `TimeUpView` | Landscape | 1600 ms hold, then results. The score counts up from 0. If the buzzer caught a card still on screen, IT WAS shows its reference and phrase. Early end says ENDED. An emptied deck says DECK CLEARED. |
| Results | `ResultsView` | Landscape | Score, BEST or NEW BEST, passed-card phrases (as written, no added quote marks), PLAY AGAIN, NEW DECK, home icon. PLAY AGAIN, NEW DECK, and home wait for a clip that is still finishing, then ask Save or Delete if it is unsaved. |
| Review | `ReviewScreen` | Landscape | Mark ticks. Jump target is the mark time minus 1 second, and a jump also plays. Tap the video to pause or play. If the player cannot open the file, it says so. |
| Library | `LibraryScreen` | Portrait | Saved clips. Empty state until one is kept. Delete removes the clip and its marks file. |

## Round rules

- The rule: the team reads the phrase out loud and may give any hints, but never says the book, chapter, or verse. The guesser names the reference. The team judges. The forehead screen, countdown, About sheet, and deck pitches all say it, and `test/copy_guard_test.dart` bans the old contradicting lines.
- One clock. The screen stamps accelerometer samples with the same elapsed time the ticker uses.
- Down ≤ −50° for 60 ms scores. Up ≥ +50° for 60 ms passes. Re-arm needs the lockout and \|θ\| ≤ 20° for 200 ms. The first card and RESUME also need \|θ\| ≤ 20° for 200 ms before a tilt counts.
- Tap mode ignores tilt. Buttons do the same scoring.
- Personal best is local, keyed by deck id and round length. The first score is BEST n. A later higher score is NEW BEST.
- ROUND N starts at 1, increments on PLAY AGAIN, and resets when the round screen closes.
- PLAY AGAIN deals cards this session has not shown first, and starts a fresh pass once every card has been shown.
- The clock shows whole seconds rounded up, so the last second reads 0:01.
- Cues live in the controller's queue, so tests drive them without a device. A correct answer is a heavy tap, then a medium tap 80 ms later. A pass is one light tap. Time up is three heavy thumps at 0, 120, and 240 ms. The count of taps tells the three apart.
- Last 10 seconds: a light tick each second from 0:10 to 0:06, then a tick every 500 ms from 0:05. Strength steps up: light at 10 to 6, medium at 5 to 4, heavy at 3 to 1. The screen edges pulse ember once a second, twice a second in the last 5, and the clock grows from 22 to 28 to 44 pt. Reduce motion holds a steady edge glow.
- Score count: starts 320 ms into time up, one tick sound and light tap per point, capped at 12 ticks, spread over at most 900 ms. The sparkle plays 100 ms after the count lands, and not at all for a score of 0. Ending early shows the score at once and sparkles when it is above 0.
- A tilt that arms the countdown plays whoomp alone. The tap-mode START opens with the first tock. A selection tap marks the next card becoming answerable: tilt mode when the phone is level again with a card showing, tap mode when the card appears.
- The screen stays awake for the whole round. The iOS idle timer is off from the round screen opening until it closes.
- Leaving the app (call, Control Center, lock) pauses a card, cancels a countdown back to the forehead screen, and freezes a flash or time-up beat. Returning applies no time gap and no urgency cues.
- Recording starts at the countdown when Record the team is on, and stops at 1.5 s into the time-up beat or when results open early.
- Review marks are timed from when the video actually started, not from the countdown. A mark that happened before the camera was ready jumps to 0:00.
- A denied camera says so. A denied microphone records video only. After a recording stops the silent-switch audio session is restored.
- A corrupt `bests.json` or `prefs.json` reads as empty or defaults. Both are written to a temp file and renamed.

## Keys used by tests

`play-hero`, `leave-round`, `review-video`, `confirm-save`, `length-30`, `length-60`, `length-90`, `book-all`, `book-ot`, `book-nt`, `book-bom`, `book-dc`, `deck-bom`, `deck-dc`, `deck-people`, `open-recordings`, `about`, `sheet-play`, `record-team`, `start-round`, `countdown`, `round-label`, `card-reference` (the answer line), `card-clue` (the phrase), `reveal-reference`, `reveal-clue`, `time-up-score`, `got-it`, `pass`, `round-clock`, `end-round`, `play-again`, `new-deck`, `home-results`, `best-line`, `round-list`, `jump-<cardId>`, `marker-<cardId>`, `save-recording`, `delete-recording`, `confirm-delete`, `library-empty`, `seek-unavailable`.

## Proof

- `flutter analyze` reports no issues.
- `flutter test` covers tilt fixtures, the round controller, lifecycle pause, clip save and delete, the camera recorder against a fake platform, the review player against a fake video platform, the book picker, lobby layout at 320 to 390 points, the card face with all 100 live phrases at 812 by 375 and 844 by 390 in tilt and tap mode, every haptic and sound cue, and each screen. Sidekick parity is Old Testament 24, New Testament 24, Book of Mormon 24, and Doctrine and Covenants 28. The same run writes `artifacts/screens/*.png`.
- Device steps are in `.cursor/skills/verify-tilt/SKILL.md`.

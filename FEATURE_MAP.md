# Feature map

The repo is https://github.com/sophomorica/scripture-up. Scripture Up 1.1.0+3. Portrait lobby, landscape round. Bundle id `com.narrowroad.scriptureup`. Team `JQ7J89B22A`.

## Screens

| Screen | Where | Orientation | Notes |
| --- | --- | --- | --- |
| Lobby | `LobbyScreen` | Portrait | Deck-first. Book of Mormon is the only PLAY. Canon tiles shake and toast. Party tiles open a sheet with PLAY disabled. |
| Deck sheet | `DeckSheet` | Portrait | Length, Record the team (off), Tilt or Tap buttons. |
| About | `AboutSheet` | Portrait | How to play, silent-switch preference, affiliation line. Long-press the title for the tilt debug line. |
| Forehead | `ForeheadView` | Landscape | `ROUND N`. Level hold arms the countdown, or START in tap mode. |
| Countdown | `CountdownView` | Landscape | 3, 2, 1 at 900 ms. `ROUND N` and GET READY. Flat phone cancels back to forehead. |
| Card | `CardPlayView` | Landscape | Full-bleed deck color. Reference and clue. Tilt hints, or PASS and GOT IT. |
| Correct / pass | flash views | Landscape | Gold got-it, amethyst pass. Timer keeps running. |
| Time's up | `TimeUpView` | Landscape | Then results. Early end says ENDED. An emptied deck says DECK CLEARED. |
| Results | `ResultsView` | Landscape | Score, BEST or NEW BEST, passed-card clues, PLAY AGAIN, NEW DECK, home icon. |
| Review | `ReviewScreen` | Landscape | Mark ticks. Jump target is the mark time minus 1 second. If the player cannot open the file, it says so. |
| Library | `LibraryScreen` | Portrait | Saved clips. Empty state until one is kept. |

## Round rules

- One clock. The screen stamps accelerometer samples with the same elapsed time the ticker uses.
- Down ≤ −50° for 60 ms scores. Up ≥ +50° for 60 ms passes. Re-arm needs the lockout and \|θ\| ≤ 20° for 200 ms.
- Tap mode ignores tilt. Buttons do the same scoring.
- Personal best is local, keyed by deck id and round length. The first score is BEST n. A later higher score is NEW BEST.
- ROUND N starts at 1, increments on PLAY AGAIN, and resets when the round screen closes.
- Recording starts at the countdown when Record the team is on, and stops at 1.5 s into the time-up beat or when results open early.

## Keys used by tests

`play-hero`, `length-30`, `length-60`, `length-90`, `deck-bom`, `deck-dc`, `deck-people`, `open-recordings`, `about`, `sheet-play`, `record-team`, `start-round`, `countdown`, `round-label`, `card-reference`, `card-clue`, `got-it`, `pass`, `round-clock`, `end-round`, `play-again`, `new-deck`, `home-results`, `best-line`, `round-list`, `jump-<cardId>`, `save-recording`, `delete-recording`, `confirm-delete`, `library-empty`, `seek-unavailable`.

## Proof

- `flutter analyze` is clean.
- `flutter test` covers tilt fixtures, the round controller, clip save/delete, each screen, and writes `artifacts/screens/*.png`.
- Device steps are in `.cursor/skills/verify-tilt/SKILL.md`.

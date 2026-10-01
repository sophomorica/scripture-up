# Verify screens

The repo is https://github.com/sophomorica/scripture-up. Each screen has a widget test and a PNG under `artifacts/screens/`.

## Commands

```bash
flutter analyze
flutter test
```

`flutter analyze` must report no issues. `flutter test` must pass, including `test/screenshot_test.dart`, which rewrites:

- `artifacts/screens/01-lobby.png`
- `artifacts/screens/02-deck-sheet.png`
- `artifacts/screens/03-forehead.png`
- `artifacts/screens/04-countdown.png`
- `artifacts/screens/05-card.png`
- `artifacts/screens/06-correct.png`
- `artifacts/screens/07-pass.png`
- `artifacts/screens/08-time-up.png`
- `artifacts/screens/09-results.png`
- `artifacts/screens/10-library-empty.png`

## What to look at

- Lobby: Book of Mormon hero, 60s selected, three coming-soon canon tiles, party tiles with NEW.
- Sheet: Book of Mormon, sample card, 30/60/90, Record the team, Tilt / Tap buttons, PLAY.
- Forehead and countdown: ROUND 1, landscape.
- Card: full-bleed blue, a reference, a clue, tilt hints.
- Correct: gold, Got it. Pass: purple, PASS.
- Results: score, BEST line, PLAY AGAIN beside NEW DECK, home icon, a passed card opened to its clue and a jump chip.

The widget tests drive the live widgets: coming-soon toast, a closed party sheet, a full tap round, pause-to-end, a camera that fails, save, the jump chip, and delete.

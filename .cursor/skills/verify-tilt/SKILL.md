# Verify tilt

Tilt is `TiltDetector` behind `TiltSensor`. Widget tests do not need a phone. Device proof does.

## On this machine

```bash
flutter test test/tilt_test.dart test/round_controller_test.dart
```

Those tests must show:

- Down past 50 degrees, held 60 ms, fires correct. Up past 50 degrees fires pass.
- A hold of 59 ms does not fire. A wobble around 40 degrees does not fire.
- After a fire, another tilt does nothing until the phone is within 20 degrees of level for 200 ms, and the lockout has passed.
- Tap mode ignores sensor samples. GOT IT and PASS still score.
- The second card does not score if the phone is still tilted from the first card.

## On an iPhone

This Linux environment has no iPhone and no simulator, so no tilt video was recorded. On a Mac:

1. Connect an iPhone 12 or newer. Run `flutter run -d <device-id>` from this directory.
2. On the lobby, tap PLAY on Book of Mormon. Leave Tilt selected. Leave Record the team off. Tap PLAY.
3. Rotate to landscape. Hold the phone on your forehead, screen toward the team, until the countdown starts by itself.
4. On a card, tilt the screen down (toward the floor) past about 50 degrees and hold it there for a moment. The gold Got it flash should show, then the next card should wait.
5. Bring the phone back to level and hold it. The next card should accept input only after that.
6. Tilt the screen up (toward the ceiling) past about 50 degrees and hold. The amethyst PASS flash should show.
7. Bring it back to level again before the following card.
8. Long-press the clock, then tap END ROUND. The results headline should say ENDED.

If the arm ring never completes, the phone is not level. Use Tap buttons in the deck sheet. PASS and GOT IT must still score.

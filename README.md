# Scripture Up

Scripture Up is a forehead party game from Narrow Road Studios. One player holds the phone sideways so the team can see a scripture reference and a short clue. Tilt the screen down when the guess is right. Tilt it up to pass. Bring it back to level before the next card.

The app is free and stores everything on the phone. There are no accounts and no purchases. The lobby is portrait. The round, from the forehead prompt through results, is landscape. The bundle id is `com.narrowroad.scriptureup`. The deployment target is iOS 15, so it runs on iPhone 12 and newer.

Version 1.2.0+5 is the doctrinal mastery build. All four books are playable in their own deck data. The lobby opens on Book of Mormon. The picker also offers ALL, OT, NT, and D&C. A canon tile selects that same book. ALL deals the four books together, 100 cards, and does not repeat a card. Old Testament, New Testament, and Book of Mormon have 24 cards each. Doctrine and Covenants has 28. Party decks are visible and not playable yet.

## TestFlight

From the repo root on a Mac:

```bash
./scripts/cut_release.sh test ios
```

That builds, signs, and uploads to TestFlight. There is no App Store submit lane. The build number is the latest App Store Connect build + 1 (`BUILD_NUMBER=N` overrides), and the build uses the Flutter version CI pins. Add `--no-upload` to build and sign the .ipa without uploading.

## Run it on an iPhone

Use a Mac with Xcode and Flutter stable. This project was built with Flutter 3.47.5.

1. Clone https://github.com/sophomorica/scripture-up and open that directory.
2. Connect an iPhone 12 or newer, or boot an iPhone 12 simulator.
3. Run `flutter pub get`.
4. Run `flutter devices` and copy the device id.
5. Run `flutter run -d <device-id>`.

The first launch asks for the camera and the microphone only if Record the team is on. That switch is off until you turn it on in the deck sheet. If the camera cannot start, the round still plays.

## Play a round

The rule is the same on every screen. The team reads the phrase out loud and may give any hints, but never says the book, chapter, or verse. The guesser names the reference. The team decides if it is right.

1. Leave the round length at 60 seconds, or choose 30 or 90.
2. Leave Book of Mormon selected, or pick another book or ALL. Tap PLAY. In the sheet, leave Tilt selected, or choose Tap buttons. Record the team stays off unless you turn it on.
3. Turn the phone sideways and hold it on your forehead. The screen faces the team. Hold it level until the countdown starts. In tap mode, press START. The forehead screen tells the guesser their job. The countdown tells the team theirs.
4. The team sees the phrase as the biggest text on the card, exactly as written, up to 44 pt. A long phrase gets a smaller size so nothing is cut off. A gold ANSWER line under it shows the reference, so the team can judge the guess.
5. Tilt the screen down past about 50 degrees and hold briefly for a correct guess. The screen flashes gold, and the phone taps heavy then medium. Tilt it up past about 50 degrees to pass. The screen flashes purple, and the phone taps once, lightly. Bring the phone back to level before the next card arms. A short tick in the hand says the next card is live. With reduce motion on, both flashes are still frames.
6. In the last 10 seconds the clock turns ember, the screen edges pulse once a second, and the phone ticks each second, lightly. In the last 5 seconds the pulse and the ticks double, the clock grows, and the taps step up from medium to heavy.
7. Time's up is three heavy thumps. The score counts up one point at a time. If the buzzer caught a card still on screen, IT WAS shows its reference and phrase. That card is not counted as a pass.
8. Long-press the clock to pause. End round from the pause screen.
9. On the results screen, tap a passed card for its phrase. PLAY AGAIN keeps the deck and raises the round number. NEW DECK and the home icon return to the lobby. An unsaved clip asks before it is dropped.

Save copies the clip into the app documents folder at `recordings/`, with a sidecar JSON of the card marks. Open a saved clip from the video button on the lobby. Delete removes that file. The app does not upload it.

## Recording and tilt

The `camera` package records the front camera at `ResolutionPreset.low`. It requests 24 fps and an 800 kbps video bitrate. If the phone rejects those settings, it records again at the same low resolution with the platform defaults. `sensors_plus` reads the accelerometer.

Tilt is behind `TiltSensor`. The detector uses the accelerometer, including gravity. Down past 50 degrees for 60 milliseconds scores. Up past 50 degrees for 60 milliseconds passes. The phone must return to within 20 degrees of level before another tilt counts. Tests drive this with scripted samples, not a device.

## Tests

Run `flutter analyze` and `flutter test`.

The tests cover the tilt threshold, hold, return-to-level, and tap fallback. They also cover the round clock and every haptic and sound cue the controller queues, the card face with all 100 live phrases at 812 by 375 and 844 by 390, the flash, countdown, and time-up views with reduce motion, personal best, save, delete, a camera that never starts, the book picker, and each screen at phone size. The four scripture decks match the Seminary Sidekick doctrinal mastery list one for one. `test/screenshot_test.dart` writes screenshot PNGs to `artifacts/screens/` in Fraunces and Barlow.

Device steps are in `.cursor/skills/verify-tilt/SKILL.md`.

Fraunces and Barlow are bundled under the SIL Open Font License. The sounds in `assets/sounds/` are CC0 recordings from freesound.org, credited in `assets/sounds/CREDITS.md` and rebuilt by `tool/sounds/build.py`.

Do not send this build to the App Store or TestFlight unless Patrick asks.

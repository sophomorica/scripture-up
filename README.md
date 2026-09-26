# Scripture Up

Scripture Up is a forehead party game from Narrow Road Studios. One player holds the phone sideways so the team can see a scripture reference and a short clue. Tilt the screen down when the guess is right. Tilt it up to pass. Bring it back to level before the next card.

The app is free and stores everything on the phone. There are no accounts and no purchases. The lobby is portrait. The round, from the forehead prompt through results, is landscape. The bundle id is `com.narrowroad.scriptureup`. The deployment target is iOS 15, so it runs on iPhone 12 and newer.

Version 1.1.0+3 is the deck-first redesign. Book of Mormon is the only live deck. The other canon decks say coming soon. Party decks are visible and not playable yet.

## Run it on an iPhone

Use a Mac with Xcode and Flutter stable. This project was built with Flutter 3.47.5.

1. Connect an iPhone 12 or newer, or boot an iPhone 12 simulator.
2. In this directory, run `flutter pub get`.
3. Run `flutter devices` and copy the device id.
4. Run `flutter run -d <device-id>`.

The first launch asks for the camera and the microphone only if Record the team is on. That switch is off until you turn it on in the deck sheet. If the camera cannot start, the round still plays.

## Play a round

1. Leave the round length at 60 seconds, or choose 30 or 90.
2. Tap PLAY on Book of Mormon. In the sheet, leave Tilt selected, or choose Tap buttons. Record the team stays off unless you turn it on.
3. Turn the phone sideways and hold it on your forehead. The screen faces the team. Hold it level until the countdown starts. In tap mode, press START.
4. Tilt the screen down past about 50 degrees and hold briefly for a correct guess. Tilt it up past about 50 degrees to pass. Bring the phone back to level before the next card arms.
5. Long-press the clock to pause. End round from the pause screen.
6. On the results screen, tap a passed card for its clue. PLAY AGAIN keeps the deck and raises the round number. NEW DECK and the home icon return to the lobby. An unsaved clip asks before it is dropped.

Save copies the clip into the app documents folder at `recordings/`, with a sidecar JSON of the card marks. Open a saved clip from the video button on the lobby. Delete removes that file. The app does not upload it.

## Recording and tilt

The `camera` package records the front camera at `ResolutionPreset.low`. It requests 24 fps and an 800 kbps video bitrate. If the phone rejects those settings, it records again at the same low resolution with the platform defaults. `sensors_plus` reads the accelerometer.

Tilt is behind `TiltSensor`. The detector uses the accelerometer, including gravity. Down past 50 degrees for 60 milliseconds scores. Up past 50 degrees for 60 milliseconds passes. The phone must return to within 20 degrees of level before another tilt counts. Tests drive this with scripted samples, not a device.

## Tests

Run `flutter analyze` and `flutter test`.

The tests cover the tilt threshold, hold, return-to-level, and tap fallback; the round clock; personal best; save, delete, and a camera that never starts; and each screen at phone size. Screenshot PNGs of the screens are written to `artifacts/screens/` by `test/screenshot_test.dart`.

This environment is Linux and cannot launch an iPhone, so it cannot record a tilt-loop video. The device steps are in `.cursor/skills/verify-tilt/SKILL.md`.

Fraunces and Barlow are bundled under the SIL Open Font License. The sounds in `assets/sounds/` are short original tones.

Do not send this build to the App Store or TestFlight unless Patrick asks.

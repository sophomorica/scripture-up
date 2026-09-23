# Scripture Up

Scripture Up is a forehead party game from Narrow Road Studios. One player holds the phone so the team can see a scripture reference and a short clue. Tilt the screen down for a correct guess. Tilt it up to pass.

The app is free and stores everything on the phone. There are no accounts and no purchases. It runs in portrait. The bundle id is `com.narrowroad.scripture_up`. The deployment target is iOS 15, so it runs on iPhone 12 and newer.

## Run it on an iPhone

Use a Mac with Xcode and Flutter stable. This project was created with Flutter 3.47.5.

1. Connect an iPhone 12 or newer, or boot an iPhone 12 simulator.
2. In this directory, run `flutter pub get`.
3. Run `flutter devices` and copy the device id.
4. Run `flutter run -d <device-id>`.

The first launch asks for the camera and the microphone. If you deny either one, the round still plays. The results screen says the camera could not start.

## Play a round

1. Leave the round length at 60 seconds, or choose 30 or 90.
2. Tap Book of Mormon. Doctrine and Covenants, Old Testament, and New Testament stay closed until those decks exist.
3. After the countdown, hold the phone on your forehead with the screen facing the team.
4. Tilt the screen down when the guess is right. Tilt it up to pass. Got it and Pass do the same thing.
5. Tap End to leave early. An unsaved clip is deleted.
6. On the results screen, tap Save recording or Delete recording.

Save copies the clip into the app documents folder at `recordings/`. Open a saved clip from Saved recordings on the home screen. Delete removes that file. The app does not upload it.

## Recording and tilt

The `camera` package records the front camera at `ResolutionPreset.low`. It requests 24 fps and an 800 kbps video bitrate. If the phone rejects those settings, it records again at the same low resolution with the platform defaults. `sensors_plus` reads the accelerometer.

A tilt counts only after the phone has been upright during the round, and only after three samples in a row. That keeps a wobble from skipping a card.

## Tests

Run `flutter test`.

The tests check the shuffle, the timer, scoring, tilt, save, delete, and a Book of Mormon round laid out at 390 by 844 points.

This environment is Linux and cannot launch an iPhone. Run `flutter run` on a Mac before you treat a device build as checked.

Do not send this build to the App Store or TestFlight unless Patrick asks.

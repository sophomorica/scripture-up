import 'package:flutter/services.dart';

import '../game/cues.dart';

abstract class GameHaptics {
  void play(HapticCue cue);
}

class DeviceHaptics implements GameHaptics {
  @override
  void play(HapticCue cue) {
    switch (cue) {
      case HapticCue.heavy:
        HapticFeedback.heavyImpact();
      case HapticCue.medium:
        HapticFeedback.mediumImpact();
      case HapticCue.light:
        HapticFeedback.lightImpact();
      case HapticCue.selection:
        HapticFeedback.selectionClick();
    }
  }
}

class SilentHaptics implements GameHaptics {
  @override
  void play(HapticCue cue) {}
}

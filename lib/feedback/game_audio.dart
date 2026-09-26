import '../game/cues.dart';

abstract class GameAudio {
  Future<void> play(SoundCue cue);
  Future<void> setRespectSilence(bool respect);
}

class SilentAudio implements GameAudio {
  @override
  Future<void> play(SoundCue cue) async {}

  @override
  Future<void> setRespectSilence(bool respect) async {}
}

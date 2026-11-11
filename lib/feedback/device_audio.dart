import 'package:audioplayers/audioplayers.dart';

import '../game/cues.dart';
import 'game_audio.dart';

class DeviceGameAudio implements GameAudio {
  DeviceGameAudio({this.respectSilence = true}) {
    _ready = _open();
  }

  bool respectSilence;
  final Map<SoundCue, AudioPlayer> _players = {};
  late final Future<void> _ready;

  Future<void> _open() async {
    await _applyContext();
    for (final cue in SoundCue.values) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource(soundFile(cue)));
      _players[cue] = player;
    }
  }

  Future<void> _applyContext() {
    return AudioPlayer.global.setAudioContext(
      audioContextFor(respectSilence: respectSilence),
    );
  }

  @override
  Future<void> setRespectSilence(bool respect) async {
    respectSilence = respect;
    await restoreSession();
  }

  @override
  Future<void> restoreSession() async {
    try {
      await _applyContext();
    } catch (_) {}
  }

  @override
  Future<void> play(SoundCue cue) async {
    try {
      await _ready;
      final player = _players[cue];
      if (player == null) {
        return;
      }
      await player.seek(Duration.zero);
      await player.resume();
    } catch (_) {}
  }
}

AudioContext audioContextFor({required bool respectSilence}) {
  return AudioContext(
    iOS: AudioContextIOS(
      category: respectSilence
          ? AVAudioSessionCategory.ambient
          : AVAudioSessionCategory.playback,
      options: respectSilence
          ? const {}
          : const {AVAudioSessionOptions.mixWithOthers},
    ),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );
}

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/feedback/device_audio.dart';

void main() {
  test('respecting the silent switch is ambient, ignoring it plays through and mixes', () {
    final respect = audioContextFor(respectSilence: true);
    expect(respect.iOS.category, AVAudioSessionCategory.ambient);
    expect(respect.iOS.options, isEmpty);

    final ignore = audioContextFor(respectSilence: false);
    expect(ignore.iOS.category, AVAudioSessionCategory.playback);
    expect(ignore.iOS.options, {AVAudioSessionOptions.mixWithOthers});
  });
}

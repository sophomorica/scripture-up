enum SoundCue {
  tock,
  tockHi,
  shing,
  correct,
  pass,
  urgency,
  urgencyFast,
  timesUp,
  sparkle,
  whoomp,
  tick,
}

enum HapticCue { heavy, medium, light, selection }

class RoundCue {
  const RoundCue({this.sound, this.haptic});

  final SoundCue? sound;
  final HapticCue? haptic;
}

String soundFile(SoundCue cue) {
  return switch (cue) {
    SoundCue.tock => 'sounds/tock.wav',
    SoundCue.tockHi => 'sounds/tock_hi.wav',
    SoundCue.shing => 'sounds/start_shing.wav',
    SoundCue.correct => 'sounds/correct.wav',
    SoundCue.pass => 'sounds/pass.wav',
    SoundCue.urgency => 'sounds/tick.wav',
    SoundCue.urgencyFast => 'sounds/urgency_tick.wav',
    SoundCue.timesUp => 'sounds/times_up.wav',
    SoundCue.sparkle => 'sounds/results_sparkle.wav',
    SoundCue.whoomp => 'sounds/whoomp.wav',
    SoundCue.tick => 'sounds/ui_tick.wav',
  };
}

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../recording/recording_store.dart';
import '../recording/round_recorder.dart';
import 'round_engine.dart';
import 'scripture_card.dart';
import 'tilt.dart';

sealed class RoundClip {
  const RoundClip();
}

class ClipOff extends RoundClip {
  const ClipOff();
}

class ClipUnavailable extends RoundClip {
  const ClipUnavailable(this.reason);

  final String reason;
}

class ClipPending extends RoundClip {
  const ClipPending(this.file);

  final File file;
}

class ClipSaved extends RoundClip {
  const ClipSaved(this.file);

  final File file;
}

class ClipDeleted extends RoundClip {
  const ClipDeleted();
}

class GameSession extends ChangeNotifier {
  GameSession({
    required this.cards,
    required this.length,
    required this.recorderFactory,
    required this.store,
    this.tilt,
    Random? random,
    DateTime Function()? clock,
    this.countdown = const Duration(seconds: 3),
    this.driveClock = true,
  }) : _random = random ?? Random(),
       _clock = clock ?? DateTime.now;

  final List<ScriptureCard> cards;
  final Duration length;
  final Duration countdown;
  final bool driveClock;
  final RoundRecorder Function() recorderFactory;
  final RecordingStore store;
  final Stream<TiltReading>? tilt;
  final Random _random;
  final DateTime Function() _clock;

  RoundPhase? phase;
  RoundClip clip = const ClipOff();
  TiltArm arm = const TiltArm(latched: true);
  String? banner;

  RoundRecorder? _recorder;
  Future<RecorderStart>? _startup;
  Timer? _ticker;
  Timer? _bannerTimer;
  StreamSubscription<TiltReading>? tiltSub;
  Future<void>? _sealFuture;
  var _discardInstead = false;
  var _closed = false;
  var _running = false;

  Future<void> start() async {
    if (_running) {
      _discardInstead = true;
      await sealRecording();
      await _dropPending();
      _ticker?.cancel();
      await tiltSub?.cancel();
      tiltSub = null;
    }
    _bannerTimer?.cancel();
    _sealFuture = null;
    _discardInstead = false;
    _running = true;
    _openRound();
    _notify();
    _bindTilt();
    if (driveClock) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        elapse(const Duration(seconds: 1));
      });
    }
    final recorder = recorderFactory();
    _recorder = recorder;
    _startup = _begin(recorder);
  }

  void elapse(Duration elapsed) {
    if (_closed || elapsed <= Duration.zero || phase == null) {
      return;
    }
    _apply(RoundTicked(elapsed));
  }

  void markCorrect() => _mark(const RoundCorrect(), 'Got it');

  void markPass() => _mark(const RoundPassed(), 'Pass');

  Future<void> saveRecording() async {
    final current = clip;
    if (current is! ClipPending) {
      return;
    }
    final saved = await store.save(current.file, id: clipId(_clock()));
    clip = ClipSaved(saved);
    _notify();
  }

  Future<void> deleteRecording() async {
    final current = clip;
    if (current is ClipPending) {
      await store.discard(current.file);
    } else if (current is ClipSaved) {
      await store.deleteSaved(current.file);
    } else {
      return;
    }
    clip = const ClipDeleted();
    _notify();
  }

  Future<void> playAgain() => start();

  Future<void> leaveRound() async {
    _discardInstead = true;
    _ticker?.cancel();
    await tiltSub?.cancel();
    tiltSub = null;
    await sealRecording();
    await _dropPending();
  }

  @visibleForTesting
  Future<void> sealRecording() {
    return _sealFuture ??= _sealBody();
  }

  void _openRound() {
    phase = startRound(
      cards: cards,
      length: length,
      random: _random,
      countdown: countdown,
    );
    arm = const TiltArm(latched: true);
    clip = const ClipOff();
    banner = null;
  }

  Future<RecorderStart> _begin(RoundRecorder recorder) async {
    const fallback = 'Camera could not start. The round still plays.';
    try {
      final result = await recorder.start();
      if (_recorder != recorder) {
        return const RecorderStart(recording: false);
      }
      if (!result.recording && !_closed && !_discardInstead) {
        clip = ClipUnavailable(result.reason ?? fallback);
        _notify();
      }
      return result;
    } catch (_) {
      if (_recorder == recorder && !_closed && !_discardInstead) {
        clip = const ClipUnavailable(fallback);
        _notify();
      }
      return const RecorderStart(recording: false, reason: fallback);
    }
  }

  void _mark(RoundEvent event, String label) {
    if (phase is! RoundPlaying) {
      return;
    }
    _apply(event);
    banner = label;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 350), () {
      banner = null;
      _notify();
    });
    _notify();
  }

  void _apply(RoundEvent event) {
    final current = phase;
    if (current == null) {
      return;
    }
    final next = reduce(current, event);
    final finished = current is! RoundFinished && next is RoundFinished;
    phase = next;
    if (finished) {
      _ticker?.cancel();
      unawaited(tiltSub?.cancel());
      tiltSub = null;
      unawaited(sealRecording());
    }
    _notify();
  }

  Future<void> _sealBody() async {
    final result =
        await (_startup ??
            Future.value(
              const RecorderStart(
                recording: false,
                reason: 'No recording this round.',
              ),
            ));
    if (!result.recording) {
      if (!_closed && !_discardInstead && clip is ClipOff) {
        clip = ClipUnavailable(result.reason ?? 'No recording this round.');
        _notify();
      }
      return;
    }
    final recorder = _recorder;
    File? file;
    if (recorder != null) {
      try {
        file = await recorder.stop();
      } catch (_) {
        file = null;
      }
    }
    if (_closed || _discardInstead) {
      if (file != null) {
        await store.discard(file);
      }
      if (!_closed && clip is! ClipSaved) {
        clip = const ClipDeleted();
        _notify();
      }
      return;
    }
    if (file == null) {
      clip = const ClipUnavailable('Recording did not finish.');
    } else {
      clip = ClipPending(file);
    }
    _notify();
  }

  Future<void> _dropPending() async {
    final current = clip;
    if (current is ClipPending) {
      await store.discard(current.file);
      clip = const ClipDeleted();
      _notify();
    }
  }

  void _bindTilt() {
    final readings = tilt;
    if (readings == null) {
      return;
    }
    try {
      tiltSub = readings.listen((reading) {
        if (phase is! RoundPlaying || _closed) {
          return;
        }
        final decision = considerTilt(arm, reading);
        arm = decision.arm;
        switch (decision.call) {
          case TiltCall.correct:
            markCorrect();
          case TiltCall.pass:
            markPass();
          case null:
            break;
        }
      }, onError: (_, _) {});
    } catch (_) {
      tiltSub = null;
    }
  }

  void _notify() {
    if (!_closed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    _discardInstead = true;
    _ticker?.cancel();
    _bannerTimer?.cancel();
    unawaited(tiltSub?.cancel());
    unawaited(sealRecording());
    super.dispose();
  }
}

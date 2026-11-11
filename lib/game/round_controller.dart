import 'dart:math';

import 'package:flutter/foundation.dart';

import '../recording/moments.dart';
import 'cues.dart';
import 'deck.dart';
import 'tilt_detector.dart';
import 'tilt_sensor.dart';

enum RoundPhase { idle, countdown, card, correct, pass, paused, timeUp, results }

const countdownBeat = Duration(milliseconds: 900);
const countdownTotal = Duration(milliseconds: 2700);
const correctFlash = Duration(milliseconds: 700);
const passFlash = Duration(milliseconds: 600);
const timeUpHold = Duration(milliseconds: 1600);
const pauseHold = Duration(milliseconds: 800);
const correctDoubleTap = Duration(milliseconds: 80);
const timeUpThumps = [Duration(milliseconds: 120), Duration(milliseconds: 240)];
const scoreCountStart = Duration(milliseconds: 320);
const scoreCountSpan = Duration(milliseconds: 900);
const scoreCountPerPoint = Duration(milliseconds: 120);
const scoreCountMaxTicks = 12;
const scoreLanding = Duration(milliseconds: 100);

const _landing = RoundCue(sound: SoundCue.sparkle, haptic: HapticCue.medium);

RoundCue _urgencyCue(int ms) {
  if (ms > 5000) {
    return const RoundCue(sound: SoundCue.urgency, haptic: HapticCue.light);
  }
  if (ms > 3000) {
    return const RoundCue(sound: SoundCue.urgencyFast, haptic: HapticCue.medium);
  }
  return const RoundCue(sound: SoundCue.urgencyFast, haptic: HapticCue.heavy);
}

final _urgencyTicks = <(Duration, RoundCue)>[
  for (var ms = 10000; ms >= 500; ms -= ms > 5000 ? 1000 : 500)
    (Duration(milliseconds: ms), _urgencyCue(ms)),
];

class RoundController extends ChangeNotifier {
  RoundController({
    required this.deck,
    required this.length,
    required this.roundNumber,
    this.tapMode = false,
    TiltConfig? config,
    Random? random,
    Set<String> unseenFirst = const {},
    this.priorBest,
  }) : _random = random ?? Random(),
       _detector = TiltDetector(config: config ?? const TiltConfig()) {
    _queue = dealCards(deck.cards, unseenFirst, _random);
  }

  final Deck deck;
  final Duration length;
  final int roundNumber;
  bool tapMode;
  final int? priorBest;
  final Random _random;
  final TiltDetector _detector;

  late List<GameCard> _queue;
  var _index = 0;
  var _phase = RoundPhase.idle;
  Duration _t = Duration.zero;
  Duration _countdownElapsed = Duration.zero;
  Duration _timeLeft = Duration.zero;
  Duration _flashElapsed = Duration.zero;
  Duration _timeUpElapsed = Duration.zero;
  Duration? _armSince;
  var _armNoted = false;
  var _got = 0;
  var _pauseHolding = false;
  Duration _pauseHeld = Duration.zero;
  var _endedEarly = false;
  var _backgrounded = false;
  var _cleared = false;
  GameCard? _revealed;
  var _countFired = 0;
  var _countLanded = false;
  var _awaitingReady = false;
  final List<RoundMark> marks = [];
  final List<RoundCue> _cues = [];
  final List<(Duration, RoundCue)> _scheduled = [];
  Duration _cueClock = Duration.zero;
  double theta = 0;
  double plane = 0;
  DetectorPhase detectorPhase = DetectorPhase.neutral;

  RoundPhase get phase => _phase;
  int get got => _got;
  int get passed => marks.where((mark) => !mark.correct).length;
  Duration get timeLeft => _timeLeft < Duration.zero ? Duration.zero : _timeLeft;
  Duration get timeUpElapsed => _timeUpElapsed;
  Duration get flashElapsed => _flashElapsed;
  double get flashProgress {
    final total = switch (_phase) {
      RoundPhase.correct => correctFlash,
      RoundPhase.pass => passFlash,
      _ => null,
    };
    if (total == null) {
      return 0;
    }
    return (_flashElapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }
  GameCard? get revealed => _revealed;
  int get shownScore {
    if (_phase != RoundPhase.timeUp) {
      return _got;
    }
    final ticks = _countTicks;
    return ticks == 0 ? 0 : (_got * _countFired / ticks).round();
  }

  int get _countTicks => min(_got, scoreCountMaxTicks);
  bool get deckCleared => _cleared;
  bool get endedEarly => _endedEarly;
  bool get urgent => _phasePlays && timeLeft <= const Duration(seconds: 10);
  bool get urgentFast => _phasePlays && timeLeft <= const Duration(seconds: 5);
  double get urgencyPulse {
    if (!urgent) {
      return 0;
    }
    final beats = urgentFast ? 2 : 1;
    final sinceTick = (1000 - timeLeft.inMilliseconds % 1000) % 1000;
    final phase = sinceTick * beats % 1000 / 1000;
    return pow(1 - phase, 2).toDouble();
  }

  bool get _phasePlays =>
      _phase == RoundPhase.card ||
      _phase == RoundPhase.correct ||
      _phase == RoundPhase.pass;

  GameCard? get current {
    if (_index < 0 || _index >= _queue.length) {
      return null;
    }
    if (_phase == RoundPhase.card ||
        _phase == RoundPhase.correct ||
        _phase == RoundPhase.pass ||
        _phase == RoundPhase.paused) {
      return _queue[_index];
    }
    return null;
  }

  double get armProgress {
    final since = _armSince;
    if (since == null || _phase != RoundPhase.idle) {
      return 0;
    }
    return ((_t - since).inMilliseconds / configArm.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  Duration get configArm => _detector.config.armDwell;

  double get pauseProgress =>
      (_pauseHeld.inMilliseconds / pauseHold.inMilliseconds).clamp(0.0, 1.0);

  int get numeral {
    final elapsed = _countdownElapsed.inMilliseconds;
    if (elapsed < countdownBeat.inMilliseconds) {
      return 3;
    }
    if (elapsed < countdownBeat.inMilliseconds * 2) {
      return 2;
    }
    return 1;
  }

  double get beatProgress {
    final beat = countdownBeat.inMilliseconds;
    final elapsed = _countdownElapsed.inMilliseconds;
    return ((elapsed % beat) / beat).clamp(0.0, 1.0);
  }

  bool get newBest => priorBest != null && _got > priorBest!;

  int get bestValue => priorBest == null ? _got : max(priorBest!, _got);

  String get bestLabel => newBest ? 'NEW BEST' : 'BEST $bestValue';

  String get headline {
    if (_cleared) {
      return 'DECK CLEARED';
    }
    if (_endedEarly) {
      return 'ENDED';
    }
    return "TIME'S UP";
  }

  List<RoundCue> drainCues() {
    final drained = List<RoundCue>.of(_cues);
    _cues.clear();
    return drained;
  }

  void elapseTo(Duration t) {
    if (t <= _t) {
      return;
    }
    if (_backgrounded) {
      _t = t;
      return;
    }
    final dt = t - _t;
    _t = t;
    _advance(dt);
    notifyListeners();
  }

  void sample(AccelSample sample) {
    if (sample.at > _t) {
      elapseTo(sample.at);
    }
    final detect =
        !_backgrounded &&
        !tapMode &&
        (_phase == RoundPhase.card ||
            _phase == RoundPhase.correct ||
            _phase == RoundPhase.pass);
    final tick = _detector.ingest(sample, detect: detect);
    theta = tick.theta;
    plane = tick.plane;
    detectorPhase = tick.phase;
    if (_backgrounded) {
      return;
    }
    if (_phase == RoundPhase.idle && !tapMode) {
      _trackArm(tick, sample.at);
    } else if (_phase == RoundPhase.countdown && tick.flat) {
      _cancelCountdown();
    } else if (_phase == RoundPhase.card && tick.fired != null) {
      _fire(tick.fired!);
    }
    _signalReady();
    notifyListeners();
  }

  void tapStart() {
    if (_phase != RoundPhase.idle) {
      return;
    }
    _enterCountdown(const RoundCue(sound: SoundCue.tock, haptic: HapticCue.selection));
    notifyListeners();
  }

  void tapCorrect() => _tap(TiltBand.correct);

  void tapPass() => _tap(TiltBand.pass);

  void beginPauseHold() {
    if (_phase != RoundPhase.card) {
      return;
    }
    _pauseHolding = true;
    _pauseHeld = Duration.zero;
    notifyListeners();
  }

  void cancelPauseHold() {
    if (!_pauseHolding) {
      return;
    }
    _pauseHolding = false;
    _pauseHeld = Duration.zero;
    notifyListeners();
  }

  void resume() {
    if (_phase != RoundPhase.paused) {
      return;
    }
    _phase = RoundPhase.card;
    _detector.requireLevel();
    notifyListeners();
  }

  void background() {
    if (_backgrounded) {
      return;
    }
    _backgrounded = true;
    _pauseHolding = false;
    _pauseHeld = Duration.zero;
    switch (_phase) {
      case RoundPhase.card:
        _phase = RoundPhase.paused;
      case RoundPhase.countdown:
        _cancelCountdown(cue: false);
      case RoundPhase.idle:
        _armSince = null;
        _armNoted = false;
      case _:
        break;
    }
    _detector.requireLevel();
    notifyListeners();
  }

  void foreground(Duration now) {
    if (now > _t) {
      _t = now;
    }
    _backgrounded = false;
    notifyListeners();
  }

  void endEarly() {
    if (_phase != RoundPhase.paused && _phase != RoundPhase.card) {
      return;
    }
    _endedEarly = true;
    _enterResults();
    if (_got > 0) {
      _cues.add(_landing);
    }
    notifyListeners();
  }

  void _tap(TiltBand band) {
    if (_phase != RoundPhase.card) {
      return;
    }
    _fire(band);
    notifyListeners();
  }

  void _trackArm(TiltTick tick, Duration at) {
    if (!tick.level) {
      _armSince = null;
      _armNoted = false;
      return;
    }
    if (_armSince == null) {
      _armSince = at;
      if (!_armNoted) {
        _armNoted = true;
        _cues.add(const RoundCue(haptic: HapticCue.light));
      }
    }
    if (_t - _armSince! >= _detector.config.armDwell) {
      _enterCountdown(
        const RoundCue(sound: SoundCue.whoomp, haptic: HapticCue.medium),
      );
    }
  }

  void _enterCountdown(RoundCue opening) {
    _phase = RoundPhase.countdown;
    _countdownElapsed = Duration.zero;
    _armSince = null;
    _cues.add(opening);
  }

  void _cancelCountdown({bool cue = true}) {
    _phase = RoundPhase.idle;
    _countdownElapsed = Duration.zero;
    _armSince = null;
    _armNoted = false;
    _detector.reset();
    if (cue) {
      _cues.add(const RoundCue(sound: SoundCue.tick));
    }
  }

  void _later(Duration delay, RoundCue cue) {
    _scheduled.add((_cueClock + delay, cue));
  }

  void _releaseDue() {
    _scheduled.removeWhere((entry) {
      if (entry.$1 > _cueClock) {
        return false;
      }
      _cues.add(entry.$2);
      return true;
    });
  }

  void _advance(Duration dt) {
    _cueClock += dt;
    _advancePhase(dt);
    _releaseDue();
  }

  void _advancePhase(Duration dt) {
    switch (_phase) {
      case RoundPhase.countdown:
        final before = _countdownElapsed;
        _countdownElapsed += dt;
        _crossBeats(before, _countdownElapsed);
        if (_countdownElapsed >= countdownTotal) {
          final overflow = _countdownElapsed - countdownTotal;
          _enterCard(first: true);
          if (overflow > Duration.zero && _phase == RoundPhase.card) {
            _tickClock(overflow);
          }
        }
        break;
      case RoundPhase.card:
        _tickClock(dt);
        if (_phase != RoundPhase.card) {
          return;
        }
        if (_pauseHolding) {
          _pauseHeld += dt;
          if (_pauseHeld >= pauseHold) {
            _pauseHolding = false;
            _phase = RoundPhase.paused;
          }
        }
        break;
      case RoundPhase.correct:
      case RoundPhase.pass:
        _tickClock(dt);
        if (_phase == RoundPhase.timeUp || _phase == RoundPhase.results) {
          return;
        }
        _flashElapsed += dt;
        final total = _phase == RoundPhase.correct ? correctFlash : passFlash;
        if (_flashElapsed >= total) {
          _advanceCard();
        }
        break;
      case RoundPhase.timeUp:
        _timeUpElapsed += dt;
        _countScore();
        if (_timeUpElapsed >= timeUpHold) {
          _enterResults();
        }
        break;
      case RoundPhase.idle:
      case RoundPhase.paused:
      case RoundPhase.results:
        break;
    }
  }

  void _countScore() {
    final ticks = _countTicks;
    final span = Duration(
      milliseconds: min(scoreCountSpan.inMilliseconds, ticks * scoreCountPerPoint.inMilliseconds),
    );
    while (_countFired < ticks &&
        _timeUpElapsed >= scoreCountStart + span * (_countFired + 1) ~/ ticks) {
      _countFired += 1;
      _cues.add(const RoundCue(sound: SoundCue.tick, haptic: HapticCue.light));
    }
    if (!_countLanded && _countFired == ticks) {
      _countLanded = true;
      if (ticks > 0) {
        _later(scoreLanding, _landing);
      }
    }
  }

  void _crossBeats(Duration before, Duration after) {
    final marks = [countdownBeat, countdownBeat * 2];
    for (final mark in marks) {
      if (before < mark && after >= mark && after < countdownTotal) {
        final beat = mark == countdownBeat ? 2 : 1;
        if (beat == 2) {
          _cues.add(
            const RoundCue(sound: SoundCue.tock, haptic: HapticCue.selection),
          );
        } else {
          _cues.add(
            const RoundCue(sound: SoundCue.tockHi, haptic: HapticCue.light),
          );
        }
      }
    }
  }

  void _tickClock(Duration dt) {
    final before = _timeLeft;
    _timeLeft -= dt;
    for (final (mark, cue) in _urgencyTicks) {
      if (before > mark && _timeLeft <= mark && _timeLeft > Duration.zero) {
        _cues.add(cue);
      }
    }
    if (_timeLeft <= Duration.zero) {
      _timeLeft = Duration.zero;
      _enterTimeUp(cleared: false);
    }
  }

  void _enterCard({required bool first}) {
    _phase = RoundPhase.card;
    _flashElapsed = Duration.zero;
    _pauseHolding = false;
    _pauseHeld = Duration.zero;
    if (first) {
      _awaitingReady = false;
      _detector.requireLevel();
      _timeLeft = length;
      _cues.add(const RoundCue(sound: SoundCue.shing, haptic: HapticCue.heavy));
    } else {
      _signalReady();
    }
  }

  void _signalReady() {
    if (!_awaitingReady || _phase != RoundPhase.card) {
      return;
    }
    if (tapMode || _detector.phase == DetectorPhase.neutral) {
      _awaitingReady = false;
      _cues.add(const RoundCue(haptic: HapticCue.selection));
    }
  }

  void _fire(TiltBand band) {
    if (_index >= _queue.length) {
      return;
    }
    final card = _queue[_index];
    final correct = band == TiltBand.correct;
    marks.add(
      RoundMark(
        cardId: card.id,
        prompt: card.prompt,
        clue: card.clue,
        correct: correct,
        tMs: _t.inMilliseconds,
      ),
    );
    if (correct) {
      _got += 1;
    }
    _phase = correct ? RoundPhase.correct : RoundPhase.pass;
    _awaitingReady = true;
    _flashElapsed = Duration.zero;
    _pauseHolding = false;
    _pauseHeld = Duration.zero;
    if (correct) {
      _cues.add(const RoundCue(sound: SoundCue.correct, haptic: HapticCue.heavy));
      _later(correctDoubleTap, const RoundCue(haptic: HapticCue.medium));
    } else {
      _cues.add(const RoundCue(sound: SoundCue.pass, haptic: HapticCue.light));
    }
  }

  void _advanceCard() {
    _index += 1;
    if (_index >= _queue.length) {
      _enterTimeUp(cleared: true);
      return;
    }
    _enterCard(first: false);
  }

  void _enterTimeUp({required bool cleared}) {
    if (_phase == RoundPhase.timeUp || _phase == RoundPhase.results) {
      return;
    }
    _cleared = cleared;
    _revealed = _phase == RoundPhase.card && _index < _queue.length ? _queue[_index] : null;
    _phase = RoundPhase.timeUp;
    _timeUpElapsed = Duration.zero;
    _countFired = 0;
    _countLanded = false;
    _awaitingReady = false;
    _scheduled.clear();
    _detector.reset();
    _cues.add(const RoundCue(sound: SoundCue.timesUp, haptic: HapticCue.heavy));
    for (final at in timeUpThumps) {
      _later(at, const RoundCue(haptic: HapticCue.heavy));
    }
  }

  void _enterResults() {
    _phase = RoundPhase.results;
  }
}

List<GameCard> dealCards(
  List<GameCard> cards,
  Set<String> unseenFirst,
  Random random,
) {
  final unseen = [
    for (final card in cards)
      if (unseenFirst.contains(card.id)) card,
  ];
  final rest = [
    for (final card in cards)
      if (!unseenFirst.contains(card.id)) card,
  ];
  _shuffle(unseen, random);
  _shuffle(rest, random);
  return [...unseen, ...rest];
}

void _shuffle(List<GameCard> cards, Random random) {
  for (var i = cards.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final swap = cards[i];
    cards[i] = cards[j];
    cards[j] = swap;
  }
}

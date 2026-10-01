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
  Duration _countdownStart = Duration.zero;
  Duration _countdownElapsed = Duration.zero;
  Duration _timeLeft = Duration.zero;
  Duration _flashElapsed = Duration.zero;
  Duration _timeUpElapsed = Duration.zero;
  Duration? _armSince;
  var _armNoted = false;
  var _got = 0;
  var _secondThump = false;
  var _pauseHolding = false;
  Duration _pauseHeld = Duration.zero;
  var _endedEarly = false;
  var _cleared = false;
  final List<RoundMark> marks = [];
  final List<RoundCue> _cues = [];
  double theta = 0;
  double plane = 0;
  DetectorPhase detectorPhase = DetectorPhase.neutral;

  RoundPhase get phase => _phase;
  int get got => _got;
  int get passed => marks.where((mark) => !mark.correct).length;
  Duration get timeLeft => _timeLeft < Duration.zero ? Duration.zero : _timeLeft;
  Duration get timeUpElapsed => _timeUpElapsed;
  Duration get flashElapsed => _flashElapsed;
  bool get deckCleared => _cleared;
  bool get endedEarly => _endedEarly;
  bool get urgent => _phasePlays && timeLeft <= const Duration(seconds: 10);
  bool get urgentFast => _phasePlays && timeLeft <= const Duration(seconds: 5);
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

  Set<String> get unseenIds {
    final seen = marks.map((mark) => mark.cardId).toSet();
    return {for (final card in deck.cards) if (!seen.contains(card.id)) card.id};
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
        !tapMode &&
        (_phase == RoundPhase.card ||
            _phase == RoundPhase.correct ||
            _phase == RoundPhase.pass);
    final tick = _detector.ingest(sample, detect: detect);
    theta = tick.theta;
    plane = tick.plane;
    detectorPhase = tick.phase;
    if (_phase == RoundPhase.idle && !tapMode) {
      _trackArm(tick, sample.at);
    } else if (_phase == RoundPhase.countdown && tick.flat) {
      _cancelCountdown();
    } else if (_phase == RoundPhase.card && tick.fired != null) {
      _fire(tick.fired!);
    }
    notifyListeners();
  }

  void tapStart() {
    if (_phase != RoundPhase.idle) {
      return;
    }
    _enterCountdown();
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
    notifyListeners();
  }

  void endEarly() {
    if (_phase != RoundPhase.paused && _phase != RoundPhase.card) {
      return;
    }
    _endedEarly = true;
    _enterResults();
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
      _cues.add(
        const RoundCue(sound: SoundCue.whoomp, haptic: HapticCue.medium),
      );
      _enterCountdown();
    }
  }

  void _enterCountdown() {
    _phase = RoundPhase.countdown;
    _countdownStart = _t;
    _countdownElapsed = Duration.zero;
    _armSince = null;
    _cues.add(const RoundCue(sound: SoundCue.tock, haptic: HapticCue.selection));
  }

  void _cancelCountdown() {
    _phase = RoundPhase.idle;
    _countdownElapsed = Duration.zero;
    _armSince = null;
    _armNoted = false;
    _detector.reset();
    _cues.add(const RoundCue(sound: SoundCue.tick));
  }

  void _advance(Duration dt) {
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
        if (!_secondThump && _timeUpElapsed >= const Duration(milliseconds: 150)) {
          _secondThump = true;
          _cues.add(const RoundCue(haptic: HapticCue.heavy));
        }
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
    if (before > const Duration(seconds: 10) &&
        _timeLeft <= const Duration(seconds: 10) &&
        _timeLeft > Duration.zero) {
      // The per-second cues below cover the 10-second mark too.
    }
    for (var second = 10; second >= 1; second--) {
      final mark = Duration(seconds: second);
      if (before > mark && _timeLeft <= mark && _timeLeft > Duration.zero) {
        if (second >= 6) {
          _cues.add(
            const RoundCue(
              sound: SoundCue.urgency,
              haptic: HapticCue.selection,
            ),
          );
        } else {
          _cues.add(
            const RoundCue(
              sound: SoundCue.urgencyFast,
              haptic: HapticCue.light,
            ),
          );
        }
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
      _timeLeft = length;
      _cues.add(const RoundCue(sound: SoundCue.shing, haptic: HapticCue.heavy));
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
        tMs: (_t - _countdownStart).inMilliseconds,
      ),
    );
    if (correct) {
      _got += 1;
    }
    _phase = correct ? RoundPhase.correct : RoundPhase.pass;
    _flashElapsed = Duration.zero;
    _pauseHolding = false;
    _pauseHeld = Duration.zero;
    _cues.add(
      correct
          ? const RoundCue(sound: SoundCue.correct, haptic: HapticCue.heavy)
          : const RoundCue(sound: SoundCue.pass, haptic: HapticCue.medium),
    );
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
    _phase = RoundPhase.timeUp;
    _timeUpElapsed = Duration.zero;
    _secondThump = false;
    _detector.reset();
    _cues.add(const RoundCue(sound: SoundCue.timesUp, haptic: HapticCue.heavy));
  }

  void _enterResults() {
    _phase = RoundPhase.results;
    _cues.add(const RoundCue(sound: SoundCue.sparkle, haptic: HapticCue.medium));
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

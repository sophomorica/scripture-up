import 'dart:math';

import 'scripture_card.dart';

sealed class RoundPhase {
  const RoundPhase();
}

class RoundCountdown extends RoundPhase {
  const RoundCountdown({
    required this.left,
    required this.queue,
    required this.length,
  });

  final Duration left;
  final List<ScriptureCard> queue;
  final Duration length;
}

class RoundPlaying extends RoundPhase {
  const RoundPlaying({
    required this.current,
    required this.queue,
    required this.correct,
    required this.passed,
    required this.timeLeft,
  });

  final ScriptureCard current;
  final List<ScriptureCard> queue;
  final List<ScriptureCard> correct;
  final List<ScriptureCard> passed;
  final Duration timeLeft;
}

class RoundFinished extends RoundPhase {
  const RoundFinished({
    required this.correct,
    required this.passed,
    required this.unseen,
    required this.deckCleared,
  });

  final List<ScriptureCard> correct;
  final List<ScriptureCard> passed;
  final List<ScriptureCard> unseen;
  final bool deckCleared;
}

sealed class RoundEvent {
  const RoundEvent();
}

class RoundTicked extends RoundEvent {
  const RoundTicked(this.elapsed);

  final Duration elapsed;
}

class RoundCorrect extends RoundEvent {
  const RoundCorrect();
}

class RoundPassed extends RoundEvent {
  const RoundPassed();
}

List<ScriptureCard> shuffledCards(List<ScriptureCard> cards, Random random) {
  final copy = List<ScriptureCard>.of(cards);
  for (var i = copy.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final swap = copy[i];
    copy[i] = copy[j];
    copy[j] = swap;
  }
  return copy;
}

RoundPhase startRound({
  required List<ScriptureCard> cards,
  required Duration length,
  Random? random,
  Duration countdown = const Duration(seconds: 3),
}) {
  if (cards.isEmpty) {
    throw ArgumentError.value(
      cards,
      'cards',
      'A round needs at least one card',
    );
  }
  if (length <= Duration.zero) {
    throw ArgumentError.value(
      length,
      'length',
      'Round length must be positive',
    );
  }
  final queue = shuffledCards(cards, random ?? Random());
  if (countdown <= Duration.zero) {
    return RoundPlaying(
      current: queue.first,
      queue: queue.sublist(1),
      correct: const [],
      passed: const [],
      timeLeft: length,
    );
  }
  return RoundCountdown(left: countdown, queue: queue, length: length);
}

RoundPhase reduce(RoundPhase phase, RoundEvent event) {
  switch (phase) {
    case RoundFinished():
      return phase;
    case RoundCountdown():
      if (event is! RoundTicked) {
        return phase;
      }
      final left = phase.left - event.elapsed;
      if (left > Duration.zero) {
        return RoundCountdown(
          left: left,
          queue: phase.queue,
          length: phase.length,
        );
      }
      return RoundPlaying(
        current: phase.queue.first,
        queue: phase.queue.sublist(1),
        correct: const [],
        passed: const [],
        timeLeft: phase.length,
      );
    case RoundPlaying():
      switch (event) {
        case RoundTicked():
          final left = phase.timeLeft - event.elapsed;
          if (left > Duration.zero) {
            return RoundPlaying(
              current: phase.current,
              queue: phase.queue,
              correct: phase.correct,
              passed: phase.passed,
              timeLeft: left,
            );
          }
          return RoundFinished(
            correct: phase.correct,
            passed: phase.passed,
            unseen: [phase.current, ...phase.queue],
            deckCleared: false,
          );
        case RoundCorrect():
          return _advance(phase, gotIt: true);
        case RoundPassed():
          return _advance(phase, gotIt: false);
      }
  }
}

RoundPhase _advance(RoundPlaying phase, {required bool gotIt}) {
  final correct = [...phase.correct, if (gotIt) phase.current];
  final passed = [...phase.passed, if (!gotIt) phase.current];
  if (phase.queue.isEmpty) {
    return RoundFinished(
      correct: correct,
      passed: passed,
      unseen: const [],
      deckCleared: true,
    );
  }
  return RoundPlaying(
    current: phase.queue.first,
    queue: phase.queue.sublist(1),
    correct: correct,
    passed: passed,
    timeLeft: phase.timeLeft,
  );
}

int countdownNumber(Duration left) {
  if (left <= Duration.zero) {
    return 1;
  }
  return (left.inMilliseconds / 1000).ceil();
}

String formatClock(Duration duration) {
  final capped = duration.inSeconds.clamp(0, 3599);
  final minutes = capped ~/ 60;
  final seconds = capped % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

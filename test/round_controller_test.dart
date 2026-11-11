import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/clock.dart';
import 'package:scripture_up/game/cues.dart';
import 'package:scripture_up/game/deck.dart';
import 'package:scripture_up/game/round_controller.dart';
import 'package:scripture_up/game/tilt_detector.dart';
import 'package:scripture_up/recording/moments.dart';

import 'tilt_test.dart' show pose;

GameCard card(String id) => GameCard(id: id, reference: id, clue: 'clue $id');

Deck deckOf(List<GameCard> cards) {
  return Deck(
    id: 'test',
    name: 'Test',
    pitch: 'Test deck',
    hero: const Color(0xFF1F4BA5),
    emblem: 'plates',
    format: DeckFormat.reference,
    status: DeckStatus.live,
    cards: cards,
  );
}

RoundController start({
  List<GameCard>? cards,
  Duration length = const Duration(seconds: 60),
  bool tap = false,
  Set<String> unseen = const {},
  int? priorBest,
  int roundNumber = 1,
  Random? random,
}) {
  return RoundController(
    deck: deckOf(cards ?? [card('a'), card('b'), card('c'), card('d')]),
    length: length,
    roundNumber: roundNumber,
    tapMode: tap,
    config: const TiltConfig(alpha: 1),
    random: random ?? Random(1),
    unseenFirst: unseen,
    priorBest: priorBest,
  );
}

List<HapticCue> haptics(RoundController controller) {
  return [
    for (final cue in controller.drainCues())
      if (cue.haptic != null) cue.haptic!,
  ];
}

RoundController playing({
  required Duration length,
  List<GameCard>? cards,
  bool tap = true,
}) {
  final controller = start(cards: cards, length: length, tap: tap);
  controller.tapStart();
  controller.elapseTo(countdownTotal);
  controller.drainCues();
  return controller;
}

void main() {
  test('unseen cards are dealt first and a round does not repeat', () {
    final dealt = dealCards(
      [card('a'), card('b'), card('c'), card('d')],
      {'b', 'd'},
      Random(2),
    );
    expect(dealt.take(2).map((entry) => entry.id).toSet(), {'b', 'd'});
    expect(dealt.skip(2).map((entry) => entry.id).toSet(), {'a', 'c'});
    expect(dealt.map((entry) => entry.id).toSet(), hasLength(4));
  });

  test('a level phone starts the countdown and a flat phone never does', () {
    final armed = start();
    armed.sample(pose(0, Duration.zero));
    expect(armed.phase, RoundPhase.idle);
    expect(armed.armProgress, 0);
    armed.sample(pose(0, const Duration(milliseconds: 599)));
    expect(armed.phase, RoundPhase.idle);
    armed.sample(pose(0, const Duration(milliseconds: 600)));
    expect(armed.phase, RoundPhase.countdown);
    expect(armed.drainCues().map((cue) => cue.sound), contains(SoundCue.whoomp));

    final flat = start();
    flat.sample(pose(-90, Duration.zero));
    flat.sample(pose(-90, const Duration(milliseconds: 1200)));
    expect(flat.phase, RoundPhase.idle);

    final dropped = start();
    dropped.sample(pose(0, Duration.zero));
    dropped.sample(pose(-70, const Duration(milliseconds: 300)));
    dropped.sample(pose(0, const Duration(milliseconds: 900)));
    expect(dropped.phase, RoundPhase.idle);
  });

  test('countdown beats are 900 ms and going flat returns to idle', () {
    final controller = start(tap: true);
    controller.tapStart();
    expect(controller.numeral, 3);
    controller.elapseTo(const Duration(milliseconds: 900));
    expect(controller.numeral, 2);
    expect(controller.phase, RoundPhase.countdown);
    controller.elapseTo(const Duration(milliseconds: 1800));
    expect(controller.numeral, 1);
    controller.sample(pose(-80, const Duration(milliseconds: 2000)));
    expect(controller.phase, RoundPhase.idle);

    final played = start(tap: true);
    played.tapStart();
    played.elapseTo(countdownTotal);
    expect(played.phase, RoundPhase.card);
    expect(played.current, isNotNull);
    expect(played.timeLeft, const Duration(seconds: 60));
    expect(
      played.drainCues().map((cue) => cue.haptic),
      contains(HapticCue.heavy),
    );
  });

  test('one tilt is one event, the timer runs through the flash, and taps work', () {
    final controller = start(length: const Duration(seconds: 10));
    controller.tapStart();
    controller.elapseTo(countdownTotal);
    final first = controller.current!.id;
    controller.sample(pose(0, countdownTotal));
    controller.sample(pose(0, countdownTotal + const Duration(milliseconds: 200)));
    controller.sample(pose(-55, countdownTotal + const Duration(milliseconds: 200)));
    controller.sample(pose(-55, countdownTotal + const Duration(milliseconds: 260)));
    expect(controller.phase, RoundPhase.correct);
    expect(controller.got, 1);
    expect(controller.marks.single.cardId, first);
    expect(controller.marks.single.tMs, 2960);
    expect(controller.marks.single.correct, isTrue);

    final during = countdownTotal + const Duration(milliseconds: 400);
    controller.elapseTo(during);
    expect(controller.phase, RoundPhase.correct);
    expect(controller.timeLeft, const Duration(milliseconds: 9600));

    controller.sample(pose(-55, during + const Duration(milliseconds: 50)));
    expect(controller.got, 1);

    final fireAt = countdownTotal + const Duration(milliseconds: 260);
    final nextCard = fireAt + correctFlash;
    controller.elapseTo(nextCard);
    expect(controller.phase, RoundPhase.card);
    expect(controller.current!.id, isNot(first));

    controller.sample(pose(-55, nextCard + const Duration(milliseconds: 20)));
    controller.sample(pose(-55, nextCard + const Duration(milliseconds: 90)));
    expect(controller.got, 1, reason: 'still locked until the phone is level');

    final levelAt = fireAt + const Duration(milliseconds: 700);
    controller.sample(pose(0, levelAt));
    controller.sample(pose(0, levelAt + const Duration(milliseconds: 200)));
    controller.sample(pose(55, levelAt + const Duration(milliseconds: 200)));
    controller.sample(pose(55, levelAt + const Duration(milliseconds: 260)));
    expect(controller.phase, RoundPhase.pass);
    expect(controller.passed, 1);

    final taps = start(tap: true, length: const Duration(seconds: 8));
    taps.tapStart();
    taps.elapseTo(countdownTotal);
    taps.sample(pose(-70, countdownTotal + const Duration(milliseconds: 100)));
    taps.sample(pose(-70, countdownTotal + const Duration(milliseconds: 200)));
    expect(taps.phase, RoundPhase.card);
    taps.tapCorrect();
    expect(taps.phase, RoundPhase.correct);
    taps.tapPass();
    expect(taps.got, 1);
  });

  test('time up drops a mid-hold tilt, then opens results', () {
    final controller = start(tap: true, length: const Duration(seconds: 2));
    controller.tapStart();
    controller.elapseTo(countdownTotal + const Duration(seconds: 2));
    expect(controller.phase, RoundPhase.timeUp);
    controller.tapCorrect();
    expect(controller.got, 0);
    controller.elapseTo(countdownTotal + const Duration(milliseconds: 3600));
    expect(controller.phase, RoundPhase.results);
    expect(controller.headline, "TIME'S UP");
    expect(controller.bestLabel, 'BEST 0');
  });

  test('clearing the deck ends the round and a better score is a new best', () {
    final controller = start(
      cards: [card('solo')],
      tap: true,
      priorBest: 0,
      roundNumber: 2,
    );
    expect(controller.roundNumber, 2);
    controller.tapStart();
    controller.elapseTo(countdownTotal);
    controller.tapPass();
    controller.elapseTo(countdownTotal + passFlash);
    expect(controller.phase, RoundPhase.timeUp);
    expect(controller.deckCleared, isTrue);
    controller.elapseTo(countdownTotal + passFlash + timeUpHold);
    expect(controller.phase, RoundPhase.results);
    expect(controller.headline, 'DECK CLEARED');
    expect(controller.newBest, isFalse);

    final beaten = start(cards: [card('solo')], tap: true, priorBest: 0);
    beaten.tapStart();
    beaten.elapseTo(countdownTotal);
    beaten.tapCorrect();
    beaten.elapseTo(countdownTotal + correctFlash);
    beaten.elapseTo(countdownTotal + correctFlash + timeUpHold);
    expect(beaten.newBest, isTrue);
    expect(beaten.bestLabel, 'NEW BEST');
  });

  test('pause freezes the clock and ignores tilt until resume', () {
    final controller = start(length: const Duration(seconds: 30));
    controller.tapStart();
    controller.elapseTo(countdownTotal);
    controller.beginPauseHold();
    controller.elapseTo(countdownTotal + const Duration(milliseconds: 799));
    expect(controller.phase, RoundPhase.card);
    controller.elapseTo(countdownTotal + pauseHold);
    expect(controller.phase, RoundPhase.paused);
    final left = controller.timeLeft;
    controller.elapseTo(countdownTotal + pauseHold + const Duration(seconds: 3));
    expect(controller.timeLeft, left);
    controller.sample(pose(-70, countdownTotal + const Duration(seconds: 2)));
    controller.sample(pose(-70, countdownTotal + const Duration(seconds: 2, milliseconds: 80)));
    expect(controller.got, 0);
    controller.resume();
    expect(controller.phase, RoundPhase.card);
    controller.beginPauseHold();
    final held = countdownTotal + pauseHold + const Duration(seconds: 3);
    controller.elapseTo(held + pauseHold);
    controller.endEarly();
    expect(controller.phase, RoundPhase.results);
    expect(controller.headline, 'ENDED');
  });

  test('resuming with the phone still tilted does not score until it returns to level', () {
    final controller = start(length: const Duration(seconds: 30));
    controller.tapStart();
    controller.elapseTo(countdownTotal);
    controller.beginPauseHold();
    var t = countdownTotal + pauseHold;
    controller.elapseTo(t);
    expect(controller.phase, RoundPhase.paused);

    controller.sample(pose(65, t));
    controller.resume();
    for (var i = 0; i < 10; i++) {
      t += const Duration(milliseconds: 20);
      controller.sample(pose(65, t));
    }
    expect(controller.phase, RoundPhase.card);
    expect(controller.got + controller.passed, 0);

    controller.sample(pose(0, t + const Duration(milliseconds: 20)));
    controller.sample(pose(0, t + const Duration(milliseconds: 240)));
    controller.sample(pose(65, t + const Duration(milliseconds: 240)));
    controller.sample(pose(65, t + const Duration(milliseconds: 300)));
    expect(controller.phase, RoundPhase.pass);
    expect(controller.passed, 1);
  });

  test('a countdown that ends tilted past the threshold does not fire card 1', () {
    final controller = start(length: const Duration(seconds: 30));
    controller.tapStart();
    var t = Duration.zero;
    while (t < countdownTotal + const Duration(milliseconds: 400)) {
      controller.sample(pose(-55, t));
      t += const Duration(milliseconds: 20);
    }
    expect(controller.phase, RoundPhase.card);
    expect(controller.got + controller.passed, 0);

    controller.sample(pose(0, t));
    controller.sample(pose(0, t + const Duration(milliseconds: 200)));
    controller.sample(pose(-55, t + const Duration(milliseconds: 200)));
    controller.sample(pose(-55, t + const Duration(milliseconds: 260)));
    expect(controller.phase, RoundPhase.correct);
    expect(controller.got, 1);
  });

  test('leaving the app pauses a card and returning applies no gap', () {
    final controller = start(tap: true, length: const Duration(seconds: 30));
    controller.tapStart();
    controller.elapseTo(countdownTotal);
    controller.elapseTo(countdownTotal + const Duration(seconds: 10));
    expect(controller.timeLeft, const Duration(seconds: 20));
    controller.drainCues();

    controller.background();
    expect(controller.phase, RoundPhase.paused);
    final away = countdownTotal + const Duration(seconds: 50);
    controller.elapseTo(away);
    controller.foreground(away);
    expect(controller.phase, RoundPhase.paused);
    expect(controller.timeLeft, const Duration(seconds: 20));
    expect(controller.drainCues(), isEmpty);

    controller.resume();
    controller.elapseTo(away + const Duration(seconds: 1));
    expect(controller.phase, RoundPhase.card);
    expect(controller.timeLeft, const Duration(seconds: 19));
  });

  test('leaving the app cancels a countdown back to the forehead screen', () {
    final controller = start(tap: true);
    controller.tapStart();
    controller.elapseTo(const Duration(milliseconds: 1000));
    controller.drainCues();

    controller.background();
    expect(controller.phase, RoundPhase.idle);
    expect(controller.drainCues(), isEmpty);
    const away = Duration(seconds: 30);
    controller.elapseTo(away);
    controller.foreground(away);
    expect(controller.phase, RoundPhase.idle);

    controller.tapStart();
    expect(controller.numeral, 3);
    controller.elapseTo(away + countdownTotal);
    expect(controller.phase, RoundPhase.card);
    expect(controller.timeLeft, const Duration(seconds: 60));
  });

  test('a flash frozen by leaving the app resumes where it stopped', () {
    final controller = start(tap: true, length: const Duration(seconds: 30));
    controller.tapStart();
    controller.elapseTo(countdownTotal);
    controller.tapCorrect();
    expect(controller.phase, RoundPhase.correct);

    controller.background();
    final away = countdownTotal + const Duration(seconds: 40);
    controller.elapseTo(away);
    controller.foreground(away);
    expect(controller.phase, RoundPhase.correct);
    expect(controller.timeLeft, const Duration(seconds: 30));

    controller.elapseTo(away + correctFlash);
    expect(controller.phase, RoundPhase.card);
    expect(controller.timeLeft, const Duration(milliseconds: 29300));
  });

  test('tilt samples while the app is away never start a countdown', () {
    final controller = start();
    controller.background();
    controller.sample(pose(0, Duration.zero));
    controller.sample(pose(0, const Duration(seconds: 2)));
    expect(controller.phase, RoundPhase.idle);
    controller.foreground(const Duration(seconds: 3));
    controller.sample(pose(0, const Duration(seconds: 3)));
    expect(controller.phase, RoundPhase.idle);
    controller.sample(pose(0, const Duration(milliseconds: 3600)));
    expect(controller.phase, RoundPhase.countdown);
  });

  test('marks sit on the round clock even when a countdown was cancelled and restarted', () {
    final controller = start(length: const Duration(seconds: 30));
    controller.sample(pose(0, Duration.zero));
    controller.sample(pose(0, const Duration(milliseconds: 600)));
    expect(controller.phase, RoundPhase.countdown);
    controller.sample(pose(-80, const Duration(milliseconds: 1000)));
    expect(controller.phase, RoundPhase.idle);

    const restart = Duration(seconds: 5);
    controller.elapseTo(restart);
    controller.tapStart();
    controller.elapseTo(restart + countdownTotal);
    controller.tapCorrect();
    expect(controller.marks.single.tMs, 7700);
  });

  test('the clock reads minutes and a jump chip backs up one second', () {
    expect(formatClock(const Duration(seconds: 90)), '1:30');
    expect(formatClock(const Duration(seconds: 2)), '0:02');
    expect(formatClock(Duration.zero), '0:00');
    expect(formatClock(const Duration(milliseconds: 1)), '0:01');
    expect(formatClock(const Duration(milliseconds: 900)), '0:01');
    expect(formatClock(const Duration(seconds: 1)), '0:01');
    expect(formatClock(const Duration(milliseconds: 1001)), '0:02');
    expect(formatClock(const Duration(milliseconds: 59100)), '1:00');
    expect(formatMark(12000), '0:12');
    expect(jumpTarget(12000), const Duration(seconds: 11));
    expect(jumpTarget(400), Duration.zero);
  });

  test('the four books are the live decks and Book of Mormon keeps its ids', () {
    final decks = Directory('assets/decks')
        .listSync()
        .whereType<File>()
        .map((file) => parseDeck(file.readAsStringSync()))
        .toList();
    final bom = decks.singleWhere((deck) => deck.id == 'bom');
    expect(bom.playable, isTrue);
    expect(bom.cards, hasLength(24));
    final first = bom.cards.singleWhere((card) => card.id == 'bom-1ne-3-7');
    expect(first.reference, '1 Nephi 3:7');
    expect(first.clue, "“I will go and do the things which the Lord hath commanded.”");
    expect(
      decks.where((deck) => deck.playable).map((deck) => deck.id).toSet(),
      {'ot', 'nt', 'bom', 'dc'},
    );
    expect(decks.singleWhere((deck) => deck.id == 'stories').cards.singleWhere((card) => card.id == 'sty-jonah').answer, 'Jonah and the Great Fish');
    for (final deck in decks) {
      for (final card in deck.cards) {
        expect(card.clueLeaks(), isFalse, reason: card.id);
        expect(card.prompt.trim(), isNotEmpty);
      }
    }
  });

  test('a correct answer is a heavy tap then a medium tap 80 ms later', () {
    final controller = playing(length: const Duration(seconds: 30));
    controller.tapCorrect();
    expect(haptics(controller), [HapticCue.heavy]);

    controller.elapseTo(countdownTotal + const Duration(milliseconds: 79));
    expect(haptics(controller), isEmpty);
    controller.elapseTo(countdownTotal + correctDoubleTap);
    expect(haptics(controller), [HapticCue.medium]);
    controller.elapseTo(countdownTotal + const Duration(milliseconds: 600));
    expect(haptics(controller), isEmpty);
  });

  test('a pass is one light tap and nothing follows it', () {
    final controller = playing(length: const Duration(seconds: 30));
    controller.tapPass();
    expect(haptics(controller), [HapticCue.light]);
    controller.elapseTo(countdownTotal + const Duration(milliseconds: 590));
    expect(haptics(controller), isEmpty);
  });

  test('the second tap of a correct answer waits out a flash frozen by leaving the app', () {
    final controller = playing(length: const Duration(seconds: 30));
    controller.tapCorrect();
    controller.drainCues();
    controller.background();
    final away = countdownTotal + const Duration(seconds: 20);
    controller.elapseTo(away);
    controller.foreground(away);
    expect(haptics(controller), isEmpty);
    controller.elapseTo(away + correctDoubleTap);
    expect(haptics(controller), [HapticCue.medium]);
  });

  test('time up is three heavy thumps and a correct answer cut off by it adds no fourth', () {
    final controller = playing(length: const Duration(seconds: 2));
    controller.elapseTo(countdownTotal + const Duration(seconds: 2));
    expect(controller.phase, RoundPhase.timeUp);
    expect(haptics(controller), [HapticCue.heavy]);
    final buzzer = countdownTotal + const Duration(seconds: 2);
    controller.elapseTo(buzzer + const Duration(milliseconds: 119));
    expect(haptics(controller), isEmpty);
    controller.elapseTo(buzzer + const Duration(milliseconds: 120));
    expect(haptics(controller), [HapticCue.heavy]);
    controller.elapseTo(buzzer + const Duration(milliseconds: 240));
    expect(haptics(controller), [HapticCue.heavy]);
    controller.elapseTo(buzzer + const Duration(milliseconds: 1000));
    expect(haptics(controller), isEmpty);

    final late = playing(length: const Duration(seconds: 2));
    late.elapseTo(countdownTotal + const Duration(milliseconds: 1980));
    late.drainCues();
    late.tapCorrect();
    late.drainCues();
    late.elapseTo(countdownTotal + const Duration(milliseconds: 2010));
    expect(late.phase, RoundPhase.timeUp);
    final cues = haptics(late);
    expect(cues.where((cue) => cue == HapticCue.medium), isEmpty);
    late.elapseTo(countdownTotal + const Duration(milliseconds: 2400));
    expect(haptics(late), [HapticCue.heavy, HapticCue.heavy]);
  });

  test('flash progress runs 0 to 1 over the flash and is 0 outside it', () {
    final controller = playing(length: const Duration(seconds: 30));
    expect(controller.flashProgress, 0);
    controller.tapCorrect();
    expect(controller.flashProgress, 0);
    controller.elapseTo(countdownTotal + const Duration(milliseconds: 350));
    expect(controller.flashProgress, closeTo(0.5, 0.001));
    controller.elapseTo(countdownTotal + correctFlash);
    expect(controller.phase, RoundPhase.card);
    expect(controller.flashProgress, 0);
    controller.tapPass();
    controller.elapseTo(countdownTotal + correctFlash + const Duration(milliseconds: 300));
    expect(controller.flashProgress, closeTo(0.5, 0.001));
  });

  test('the last ten seconds tick on the second, then every half second, and step up in strength', () {
    final controller = playing(length: const Duration(seconds: 12));
    final ticks = <int, RoundCue>{};
    var elapsed = countdownTotal;
    while (controller.timeLeft > Duration.zero) {
      elapsed += const Duration(milliseconds: 100);
      controller.elapseTo(elapsed);
      for (final cue in controller.drainCues()) {
        if (cue.sound == SoundCue.urgency || cue.sound == SoundCue.urgencyFast) {
          ticks[controller.timeLeft.inMilliseconds] = cue;
        }
      }
    }
    expect(ticks.keys.toList(), [
      10000, 9000, 8000, 7000, 6000,
      5000, 4500, 4000, 3500, 3000, 2500, 2000, 1500, 1000, 500,
    ]);
    for (final ms in [10000, 9000, 8000, 7000, 6000]) {
      expect(ticks[ms]!.haptic, HapticCue.light, reason: '$ms');
      expect(ticks[ms]!.sound, SoundCue.urgency, reason: '$ms');
    }
    for (final ms in [5000, 4500, 4000, 3500]) {
      expect(ticks[ms]!.haptic, HapticCue.medium, reason: '$ms');
      expect(ticks[ms]!.sound, SoundCue.urgencyFast, reason: '$ms');
    }
    for (final ms in [3000, 2500, 2000, 1500, 1000, 500]) {
      expect(ticks[ms]!.haptic, HapticCue.heavy, reason: '$ms');
      expect(ticks[ms]!.sound, SoundCue.urgencyFast, reason: '$ms');
    }
  });

  test('a round of ten seconds or less ticks only from the marks it passes', () {
    final controller = playing(length: const Duration(seconds: 10));
    controller.elapseTo(countdownTotal + const Duration(milliseconds: 100));
    final first = controller.drainCues();
    expect(first.where((cue) => cue.sound == SoundCue.urgency), isEmpty);
    controller.elapseTo(countdownTotal + const Duration(milliseconds: 1000));
    expect(
      controller.drainCues().where((cue) => cue.sound == SoundCue.urgency),
      hasLength(1),
    );
  });

  test('the edge pulse peaks on each tick, once a second, then twice a second in the last five', () {
    final controller = playing(length: const Duration(seconds: 30));
    expect(controller.urgencyPulse, 0);
    controller.elapseTo(countdownTotal + const Duration(milliseconds: 19500));
    expect(controller.urgent, isFalse);
    expect(controller.urgencyPulse, 0);

    double at(int timeLeftMs) {
      controller.elapseTo(countdownTotal + Duration(milliseconds: 30000 - timeLeftMs));
      return controller.urgencyPulse;
    }

    expect(at(9999), greaterThan(0.99));
    expect(at(9750), closeTo(0.5625, 0.01));
    expect(at(9500), closeTo(0.25, 0.01));
    expect(at(9010), lessThan(0.01));
    expect(at(8999), greaterThan(0.99));

    expect(at(5999), greaterThan(0.99));
    expect(at(5500), closeTo(0.25, 0.01));
    expect(at(4999), greaterThan(0.99));
    expect(at(4750), closeTo(0.25, 0.01));
    expect(at(4510), lessThan(0.01));
    expect(at(4499), greaterThan(0.99));
    expect(at(4250), closeTo(0.25, 0.01));
    expect(at(3999), greaterThan(0.99));
  });

  test('the edge pulse is off while paused, in the card flash it keeps beating, and after time up it stops', () {
    final controller = playing(length: const Duration(seconds: 12));
    controller.elapseTo(countdownTotal + const Duration(milliseconds: 2500));
    expect(controller.urgent, isTrue);
    controller.tapCorrect();
    expect(controller.phase, RoundPhase.correct);
    expect(controller.urgencyPulse, greaterThan(0));
    controller.elapseTo(countdownTotal + const Duration(seconds: 12, milliseconds: 100));
    expect(controller.phase, RoundPhase.timeUp);
    expect(controller.urgencyPulse, 0);

    final paused = playing(length: const Duration(seconds: 12));
    paused.elapseTo(countdownTotal + const Duration(milliseconds: 2500));
    paused.background();
    expect(paused.phase, RoundPhase.paused);
    expect(paused.urgencyPulse, 0);
  });

  List<GameCard> manyCards(int count) => [for (var i = 0; i < count; i++) card('c$i')];

  RoundController scored(int points, {int length = 120}) {
    final controller = playing(
      length: Duration(seconds: length),
      cards: manyCards(points + 5),
    );
    var at = countdownTotal;
    for (var i = 0; i < points; i++) {
      controller.tapCorrect();
      at += correctFlash;
      controller.elapseTo(at);
    }
    controller.drainCues();
    controller.elapseTo(countdownTotal + Duration(seconds: length));
    expect(controller.phase, RoundPhase.timeUp);
    controller.drainCues();
    return controller;
  }

  (List<(int, RoundCue)>, List<int>) countThrough(RoundController controller) {
    final cues = <(int, RoundCue)>[];
    final shown = <int>[];
    final buzzer = countdownTotal + Duration(seconds: controller.length.inSeconds);
    for (var ms = 10; ms <= 1700; ms += 10) {
      controller.elapseTo(buzzer + Duration(milliseconds: ms));
      for (final cue in controller.drainCues()) {
        cues.add((ms, cue));
      }
      shown.add(controller.shownScore);
    }
    return (cues, shown);
  }

  test('the score counts up from zero, a tick and a light tap per point, then the sparkle lands', () {
    final controller = scored(5);
    expect(controller.shownScore, 0);
    final (cues, shown) = countThrough(controller);

    final ticks = [
      for (final (ms, cue) in cues)
        if (cue.sound == SoundCue.tick) ms,
    ];
    expect(ticks, [440, 560, 680, 800, 920]);
    for (final (_, cue) in cues.where((entry) => entry.$2.sound == SoundCue.tick)) {
      expect(cue.haptic, HapticCue.light);
    }
    expect(shown[42], 0);
    expect(shown[43], 1);
    expect(shown[91], 5);
    expect(shown.last, 5);

    final sparkle = cues.where((entry) => entry.$2.sound == SoundCue.sparkle).toList();
    expect(sparkle, hasLength(1));
    expect(sparkle.single.$1, 1020);
    expect(sparkle.single.$1, greaterThan(ticks.last));
    expect(sparkle.single.$2.haptic, HapticCue.medium);
    expect(controller.phase, RoundPhase.results);
    expect(controller.shownScore, 5);
  });

  test('a big score caps its ticks at twelve inside about 900 ms and still lands on the real number', () {
    final controller = scored(30);
    final (cues, shown) = countThrough(controller);
    final ticks = [
      for (final (ms, cue) in cues)
        if (cue.sound == SoundCue.tick) ms,
    ];
    expect(ticks, hasLength(scoreCountMaxTicks));
    expect(ticks.first, 400);
    expect(ticks.last, 1220);
    expect(shown.last, 30);
    expect(shown.toSet().length, lessThanOrEqualTo(scoreCountMaxTicks + 1));
    expect(
      cues.where((entry) => entry.$2.sound == SoundCue.sparkle).single.$1,
      greaterThan(ticks.last),
    );
  });

  test('one point ticks once and a score of zero neither ticks nor sparkles', () {
    final one = scored(1);
    final (oneCues, oneShown) = countThrough(one);
    expect(oneCues.where((entry) => entry.$2.sound == SoundCue.tick), hasLength(1));
    expect(oneCues.where((entry) => entry.$2.sound == SoundCue.sparkle), hasLength(1));
    expect(oneShown.last, 1);

    final none = playing(length: const Duration(seconds: 3));
    none.elapseTo(countdownTotal + const Duration(seconds: 3));
    none.drainCues();
    final (noneCues, noneShown) = countThrough(none);
    expect(noneCues.where((entry) => entry.$2.sound == SoundCue.tick), isEmpty);
    expect(noneCues.where((entry) => entry.$2.sound == SoundCue.sparkle), isEmpty);
    expect(noneShown.toSet(), {0});
  });

  test('ending early lands the score at once, with a sparkle only when there is a score', () {
    final controller = playing(length: const Duration(seconds: 30), cards: manyCards(5));
    controller.tapCorrect();
    controller.elapseTo(countdownTotal + correctFlash);
    controller.drainCues();
    controller.endEarly();
    expect(controller.phase, RoundPhase.results);
    expect(controller.shownScore, 1);
    expect(
      controller.drainCues().where((cue) => cue.sound == SoundCue.sparkle),
      hasLength(1),
    );

    final empty = playing(length: const Duration(seconds: 30));
    empty.endEarly();
    expect(empty.drainCues().where((cue) => cue.sound == SoundCue.sparkle), isEmpty);
  });

  test('time up on a card still in play reveals it without marking it', () {
    final controller = playing(length: const Duration(seconds: 3), cards: manyCards(5));
    controller.tapPass();
    controller.elapseTo(countdownTotal + passFlash);
    final onScreen = controller.current!;
    controller.elapseTo(countdownTotal + const Duration(seconds: 3));
    expect(controller.phase, RoundPhase.timeUp);
    expect(controller.revealed, same(onScreen));
    expect(controller.marks.map((mark) => mark.cardId), isNot(contains(onScreen.id)));
    expect(controller.marks, hasLength(1));
    expect(controller.current, isNull);
  });

  test('time up during a flash, or after the last card, has nothing to reveal', () {
    final flash = playing(length: const Duration(seconds: 3), cards: manyCards(5));
    flash.elapseTo(countdownTotal + const Duration(milliseconds: 2900));
    flash.tapCorrect();
    flash.elapseTo(countdownTotal + const Duration(seconds: 3));
    expect(flash.phase, RoundPhase.timeUp);
    expect(flash.revealed, isNull);
    expect(flash.marks, hasLength(1));

    final cleared = playing(length: const Duration(seconds: 30), cards: [card('only')]);
    cleared.tapPass();
    cleared.elapseTo(countdownTotal + passFlash);
    expect(cleared.phase, RoundPhase.timeUp);
    expect(cleared.deckCleared, isTrue);
    expect(cleared.revealed, isNull);
  });

  test('a tilt that arms the countdown plays whoomp alone, and a tap start still opens with the tock', () {
    final armed = start();
    armed.sample(pose(0, Duration.zero));
    armed.drainCues();
    armed.sample(pose(0, const Duration(milliseconds: 600)));
    expect(armed.phase, RoundPhase.countdown);
    final sounds = armed.drainCues().map((cue) => cue.sound).toList();
    expect(sounds, [SoundCue.whoomp]);
    armed.elapseTo(const Duration(milliseconds: 600) + countdownBeat);
    expect(armed.drainCues().map((cue) => cue.sound), [SoundCue.tock]);

    final tapped = start(tap: true);
    tapped.tapStart();
    expect(tapped.drainCues().map((cue) => cue.sound), [SoundCue.tock]);
  });

  test('tap mode gives a selection tap when the next card appears, and the first card does not', () {
    final controller = playing(length: const Duration(seconds: 30));
    expect(haptics(controller), isEmpty);
    controller.tapPass();
    controller.drainCues();
    controller.elapseTo(countdownTotal + passFlash - const Duration(milliseconds: 1));
    expect(haptics(controller), isEmpty);
    controller.elapseTo(countdownTotal + passFlash);
    expect(controller.phase, RoundPhase.card);
    expect(haptics(controller), [HapticCue.selection]);
    controller.elapseTo(countdownTotal + const Duration(seconds: 3));
    expect(haptics(controller), isEmpty);
  });

  test('tilt mode gives the selection tap when the phone is level again with a card showing', () {
    final controller = start(length: const Duration(seconds: 30));
    controller.tapStart();
    controller.elapseTo(countdownTotal);
    controller.sample(pose(0, countdownTotal));
    controller.sample(pose(0, countdownTotal + const Duration(milliseconds: 200)));
    controller.sample(pose(-55, countdownTotal + const Duration(milliseconds: 200)));
    controller.sample(pose(-55, countdownTotal + const Duration(milliseconds: 260)));
    expect(controller.phase, RoundPhase.correct);
    final fireAt = countdownTotal + const Duration(milliseconds: 260);
    controller.elapseTo(fireAt + correctDoubleTap);
    controller.drainCues();

    controller.sample(pose(-55, fireAt + correctFlash));
    expect(controller.phase, RoundPhase.card);
    expect(haptics(controller), isEmpty, reason: 'still tilted, not answerable yet');

    final levelAt = fireAt + const Duration(milliseconds: 750);
    controller.sample(pose(0, levelAt));
    expect(haptics(controller), isEmpty);
    controller.sample(pose(0, levelAt + const Duration(milliseconds: 199)));
    expect(haptics(controller), isEmpty);
    controller.sample(pose(0, levelAt + const Duration(milliseconds: 200)));
    expect(haptics(controller), [HapticCue.selection]);
    controller.sample(pose(0, levelAt + const Duration(milliseconds: 400)));
    expect(haptics(controller), isEmpty);
  });

  test('tilt mode taps at once when the phone was already level as the flash ended', () {
    final controller = start(length: const Duration(seconds: 30));
    controller.tapStart();
    controller.elapseTo(countdownTotal);
    controller.sample(pose(0, countdownTotal));
    controller.sample(pose(0, countdownTotal + const Duration(milliseconds: 200)));
    controller.sample(pose(-55, countdownTotal + const Duration(milliseconds: 200)));
    controller.sample(pose(-55, countdownTotal + const Duration(milliseconds: 260)));
    final fireAt = countdownTotal + const Duration(milliseconds: 260);
    controller.elapseTo(fireAt + correctDoubleTap);
    controller.drainCues();

    controller.sample(pose(0, fireAt + const Duration(milliseconds: 300)));
    controller.sample(pose(0, fireAt + const Duration(milliseconds: 650)));
    expect(controller.phase, RoundPhase.correct);
    controller.sample(pose(0, fireAt + const Duration(milliseconds: 705)));
    expect(controller.phase, RoundPhase.card);
    expect(haptics(controller), [HapticCue.selection]);
  });
}

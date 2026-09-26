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
    controller.sample(pose(-55, countdownTotal));
    controller.sample(pose(-55, countdownTotal + const Duration(milliseconds: 60)));
    expect(controller.phase, RoundPhase.correct);
    expect(controller.got, 1);
    expect(controller.marks.single.cardId, first);
    expect(controller.marks.single.tMs, 2760);
    expect(controller.marks.single.correct, isTrue);

    final during = countdownTotal + const Duration(milliseconds: 400);
    controller.elapseTo(during);
    expect(controller.phase, RoundPhase.correct);
    expect(controller.timeLeft, const Duration(milliseconds: 9600));

    controller.sample(pose(-55, during + const Duration(milliseconds: 50)));
    expect(controller.got, 1);

    final fireAt = countdownTotal + const Duration(milliseconds: 60);
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
    expect(controller.unseenIds, isEmpty);
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

  test('the clock reads minutes and a jump chip backs up one second', () {
    expect(formatClock(const Duration(seconds: 90)), '1:30');
    expect(formatClock(const Duration(seconds: 2)), '0:02');
    expect(formatMark(12000), '0:12');
    expect(jumpTarget(12000), const Duration(seconds: 11));
    expect(jumpTarget(400), Duration.zero);
  });

  test('the Book of Mormon deck is the only live deck and keeps its ids', () {
    final decks = Directory('assets/decks')
        .listSync()
        .whereType<File>()
        .map((file) => parseDeck(file.readAsStringSync()))
        .toList();
    final bom = decks.singleWhere((deck) => deck.id == 'bom');
    expect(bom.playable, isTrue);
    expect(bom.cards, hasLength(18));
    expect(
      bom.cards.map((card) => card.reference),
      containsAll([
        '1 Nephi 3:7',
        '1 Nephi 1:1',
        '3 Nephi 11:10',
        'Ether 12:27',
        'Moroni 10:4',
      ]),
    );
    final name = bom.cards.singleWhere((card) => card.id == 'bom-3ne-11-10');
    expect(name.reference, '3 Nephi 11:10');
    expect(name.clue, 'He speaks his own name');
    expect(decks.where((deck) => deck.playable), hasLength(1));
    expect(decks.singleWhere((deck) => deck.id == 'nt').cards.singleWhere((card) => card.id == 'nt-john-11-35').clue, 'Two words in the King James');
    expect(decks.singleWhere((deck) => deck.id == 'stories').cards.singleWhere((card) => card.id == 'sty-jonah').answer, 'Jonah and the Great Fish');
    for (final deck in decks) {
      for (final card in deck.cards) {
        expect(card.clueLeaks(), isFalse, reason: card.id);
        expect(card.prompt.trim(), isNotEmpty);
      }
    }
  });
}

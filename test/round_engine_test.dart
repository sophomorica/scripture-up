import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/decks.dart';
import 'package:scripture_up/game/round_engine.dart';
import 'package:scripture_up/game/scripture_card.dart';

ScriptureCard card(String id) {
  return ScriptureCard(id: id, reference: id, clue: 'clue $id');
}

void main() {
  final deck = [card('a'), card('b'), card('c'), card('d')];

  test('a seeded shuffle keeps every card and a stable order', () {
    final round = startRound(
      cards: deck,
      length: const Duration(seconds: 60),
      random: Random(1),
      countdown: Duration.zero,
    ) as RoundPlaying;

    expect(round.current.id, 'c');
    expect(round.queue.map((entry) => entry.id).toList(), ['b', 'd', 'a']);
    expect(deck.map((entry) => entry.id).toList(), ['a', 'b', 'c', 'd']);
    expect(round.timeLeft, const Duration(seconds: 60));
    expect(round.correct, isEmpty);
    expect(round.passed, isEmpty);
  });

  test('correct scores and advances, pass does not score', () {
    var round = startRound(
      cards: deck,
      length: const Duration(seconds: 60),
      random: Random(1),
      countdown: Duration.zero,
    );

    round = reduce(round, const RoundCorrect());
    final playing = round as RoundPlaying;
    expect(playing.correct.map((entry) => entry.id).toList(), ['c']);
    expect(playing.passed, isEmpty);
    expect(playing.current.id, 'b');

    round = reduce(round, const RoundPassed());
    final afterPass = round as RoundPlaying;
    expect(afterPass.correct.map((entry) => entry.id).toList(), ['c']);
    expect(afterPass.passed.map((entry) => entry.id).toList(), ['b']);
    expect(afterPass.current.id, 'd');
    expect(afterPass.timeLeft, const Duration(seconds: 60));
  });

  test('the clock ignores guesses during the countdown', () {
    var round = startRound(
      cards: deck,
      length: const Duration(seconds: 60),
      random: Random(1),
    ) as RoundCountdown;

    expect(countdownNumber(round.left), 3);
    round = reduce(round, const RoundCorrect()) as RoundCountdown;
    round = reduce(round, const RoundPassed()) as RoundCountdown;
    expect(round.queue.first.id, 'c');

    round = reduce(
      round,
      const RoundTicked(Duration(seconds: 1)),
    ) as RoundCountdown;
    expect(countdownNumber(round.left), 2);
    round = reduce(
      round,
      const RoundTicked(Duration(seconds: 1)),
    ) as RoundCountdown;
    expect(countdownNumber(round.left), 1);

    final playing =
        reduce(round, const RoundTicked(Duration(seconds: 1))) as RoundPlaying;
    expect(playing.current.id, 'c');
    expect(playing.timeLeft, const Duration(seconds: 60));
  });

  test('time running out leaves the open card unseen', () {
    var round = startRound(
      cards: deck,
      length: const Duration(seconds: 2),
      random: Random(1),
      countdown: Duration.zero,
    );
    round = reduce(round, const RoundCorrect());
    round = reduce(round, const RoundTicked(Duration(seconds: 2)));
    final finished = round as RoundFinished;

    expect(finished.correct.map((entry) => entry.id).toList(), ['c']);
    expect(finished.passed, isEmpty);
    expect(finished.unseen.map((entry) => entry.id).toList(), ['b', 'd', 'a']);
    expect(finished.deckCleared, isFalse);

    final ignored = reduce(finished, const RoundCorrect()) as RoundFinished;
    expect(ignored.correct.map((entry) => entry.id).toList(), ['c']);
  });

  test('the last card ends the round with the deck cleared', () {
    final only = [card('solo')];
    var round = startRound(
      cards: only,
      length: const Duration(seconds: 30),
      countdown: Duration.zero,
    );
    round = reduce(round, const RoundPassed());
    final finished = round as RoundFinished;
    expect(finished.passed.single.id, 'solo');
    expect(finished.correct, isEmpty);
    expect(finished.unseen, isEmpty);
    expect(finished.deckCleared, isTrue);
  });

  test('an empty deck or a zero length cannot start', () {
    expect(
      () => startRound(cards: const [], length: const Duration(seconds: 60)),
      throwsArgumentError,
    );
    expect(
      () => startRound(cards: deck, length: Duration.zero),
      throwsArgumentError,
    );
  });

  test('the clock reads minutes and seconds', () {
    expect(formatClock(const Duration(seconds: 90)), '1:30');
    expect(formatClock(const Duration(seconds: 2)), '0:02');
    expect(formatClock(Duration.zero), '0:00');
    expect(countdownNumber(const Duration(milliseconds: 1001)), 2);
  });

  test('the Book of Mormon deck is playable and the others are not', () {
    expect(bookOfMormonDeck.cards.length, inInclusiveRange(12, 20));
    expect(bookOfMormonDeck.playable, isTrue);
    expect(doctrineAndCovenantsDeck.playable, isFalse);
    expect(oldTestamentDeck.playable, isFalse);
    expect(newTestamentDeck.playable, isFalse);

    final references = bookOfMormonDeck.cards
        .map((entry) => entry.reference)
        .toSet();
    expect(
      references,
      containsAll([
        '1 Nephi 3:7',
        '1 Nephi 1:1',
        '2 Nephi 2:25',
        '2 Nephi 9:28',
        'Mosiah 2:17',
        'Alma 32:21',
        'Alma 37:6',
        'Helaman 5:12',
        '3 Nephi 11:10',
        'Ether 12:27',
        'Moroni 10:4',
        '1 Nephi 16:10',
      ]),
    );

    final liahona = bookOfMormonDeck.cards.singleWhere(
      (entry) => entry.reference == '1 Nephi 16:10',
    );
    expect(liahona.clue, 'A ball of curious workmanship');

    final ids = bookOfMormonDeck.cards.map((entry) => entry.id).toSet();
    expect(ids.length, bookOfMormonDeck.cards.length);
    for (final entry in bookOfMormonDeck.cards) {
      expect(entry.reference.trim(), isNotEmpty);
      expect(entry.clue.trim(), isNotEmpty);
      expect(entry.clue.length, lessThan(48));
      expect(entry.clue.contains('\n'), isFalse);
    }
  });
}

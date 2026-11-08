import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/deck.dart';

void main() {
  final source =
      (jsonDecode(
            File('test/fixtures/sidekick_doctrinal_mastery.json')
                .readAsStringSync(),
          ) as Map<String, Object?>)['scriptures']!
          as List<Object?>;
  const books = {
    'ot': 'oldTestament',
    'nt': 'newTestament',
    'bom': 'bookOfMormon',
    'dc': 'doctrineAndCovenants',
  };
  const counts = {'ot': 24, 'nt': 24, 'bom': 24, 'dc': 28};

  test('Sidekick source covers all 100 doctrinal mastery passages', () {
    expect(source, hasLength(100));
  });

  for (final MapEntry(key: deckId, value: book) in books.entries) {
    test('$deckId deck matches Sidekick $book one for one', () {
      final deck = parseDeck(
        File('assets/decks/$deckId.json').readAsStringSync(),
      );
      final expected = [
        for (final entry in source.cast<Map<String, Object?>>())
          if (entry['book'] == book)
            (entry['reference']! as String, entry['keyPhrase']! as String),
      ];
      final actual = [
        for (final card in deck.cards) (card.reference!, card.clue),
      ];
      expect(expected, hasLength(counts[deckId]));
      expect(actual, expected);
      expect(
        deck.cards.map((card) => card.id).toSet(),
        hasLength(deck.cards.length),
      );
    });
  }
}

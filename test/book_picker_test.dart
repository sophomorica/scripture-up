import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/deck.dart';
import 'package:scripture_up/game/round_controller.dart';
import 'package:scripture_up/ui/style.dart';

import 'widget_test.dart' show loadDecks, pumpGame;

const _bookIds = ['ot', 'nt', 'bom', 'dc'];
const _bookCounts = {'ot': 24, 'nt': 24, 'bom': 24, 'dc': 28};

void main() {
  test('all is the four books once, then a dealt shuffle', () {
    final decks = loadDecks();
    final books = [
      for (final id in _bookIds) decks.firstWhere((deck) => deck.id == id),
    ];
    expect({for (final deck in books) deck.id: deck.cardCount}, _bookCounts);
    final union = [
      for (final deck in books) ...deck.cards.map((card) => card.id),
    ];
    expect(union.toSet(), hasLength(100));

    final all = bookDeck(decks, 'all')!;
    expect(all.playable, isTrue);
    expect(all.cards, hasLength(100));
    expect(all.cards.map((card) => card.id).toSet(), union.toSet());

    final dealt = dealCards(
      all.cards,
      const {},
      Random(7),
    ).map((card) => card.id).toList();
    expect(dealt, hasLength(100));
    expect(dealt.toSet(), union.toSet());
    expect(dealt, isNot(all.cards.map((card) => card.id).toList()));
  });

  test('each book filter returns only that book', () {
    final decks = loadDecks();
    for (final id in _bookIds) {
      final source = decks.firstWhere((deck) => deck.id == id);
      final picked = bookDeck(decks, id)!;
      expect(picked.id, id);
      expect(picked.playable, isTrue);
      expect(
        picked.cards.map((card) => card.id).toList(),
        source.cards.map((card) => card.id).toList(),
      );
    }
    expect(bookDeck(decks, 'nope'), isNull);
  });

  testWidgets('the picker and the canon tiles select the same book', (
    tester,
  ) async {
    final dir = await pumpGame(tester);
    addTearDown(() => dir.deleteSync(recursive: true));

    Color? chipColor(String id) {
      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(Key('book-$id')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (container.decoration! as BoxDecoration).color;
    }

    void expectSelected(String id) {
      for (final other in bookPickerIds) {
        expect(chipColor(other), other == id ? goldLeaf : Colors.transparent);
      }
    }

    expect(find.text('Book of Mormon'), findsOneWidget);
    expect(find.text('24 CARDS · REFERENCE + CLUE'), findsOneWidget);
    expectSelected('bom');

    await tester.tap(find.byKey(const Key('deck-ot')));
    await tester.pumpAndSettle();
    expect(find.text('Old Testament'), findsWidgets);
    expect(find.text('24 CARDS · REFERENCE + CLUE'), findsOneWidget);
    expectSelected('ot');

    await tester.tap(find.byKey(const Key('book-nt')));
    await tester.pumpAndSettle();
    expect(find.text('New Testament'), findsWidgets);
    expect(find.text('24 CARDS · REFERENCE + CLUE'), findsOneWidget);
    expectSelected('nt');

    await tester.tap(find.byKey(const Key('deck-dc')));
    await tester.pumpAndSettle();
    expect(find.text('Doctrine and Covenants'), findsWidgets);
    expect(find.text('28 CARDS · REFERENCE + CLUE'), findsOneWidget);
    expectSelected('dc');

    await tester.tap(find.byKey(const Key('book-all')));
    await tester.pumpAndSettle();
    expect(find.text('All Books'), findsOneWidget);
    expect(find.text('100 CARDS · REFERENCE + CLUE'), findsOneWidget);
    expectSelected('all');

    await tester.tap(find.byKey(const Key('book-bom')));
    await tester.pumpAndSettle();
    expect(find.text('Book of Mormon'), findsOneWidget);
    expect(find.text('24 CARDS · REFERENCE + CLUE'), findsOneWidget);
    expectSelected('bom');
  });
}

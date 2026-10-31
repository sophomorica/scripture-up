import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/deck.dart';

import 'widget_test.dart' show loadDecks, pumpGame;

void main() {
  test('all merges every book and is playable', () {
    final decks = loadDecks();
    final all = bookDeck(decks, 'all')!;
    final sum = ['ot', 'nt', 'bom', 'dc']
        .map((id) => decks.firstWhere((d) => d.id == id).cardCount)
        .reduce((a, b) => a + b);
    expect(all.cardCount, sum);
    expect(all.playable, isTrue);
  });

  test('each book opens on its own even if marked soon', () {
    final decks = loadDecks();
    for (final id in ['ot', 'nt', 'bom', 'dc']) {
      final d = bookDeck(decks, id)!;
      expect(d.id, id);
      expect(d.playable, isTrue);
    }
    expect(bookDeck(decks, 'nope'), isNull);
  });

  testWidgets('picker swaps the hero deck', (tester) async {
    final dir = await pumpGame(tester);
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(find.text('Book of Mormon'), findsWidgets);
    await tester.tap(find.byKey(const Key('book-dc')));
    await tester.pumpAndSettle();
    expect(find.text('Doctrine and Covenants'), findsWidgets);
    await tester.tap(find.byKey(const Key('book-all')));
    await tester.pumpAndSettle();
    expect(find.text('All Books'), findsOneWidget);
  });
}

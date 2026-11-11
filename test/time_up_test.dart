import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_fonts.dart';
import 'widget_test.dart' show beginCard, pumpGame, startTapRound;

String shownScore(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('time-up-score'))).data!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets('time up on a card still in play shows IT WAS with its reference and phrase', (tester) async {
    await pumpGame(tester);
    await startTapRound(tester);
    await beginCard(tester);
    await tester.tap(find.byKey(const Key('got-it')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final reference = tester.widget<Text>(find.byKey(const Key('card-reference'))).data!;
    final phrase = tester.widget<Text>(find.byKey(const Key('card-clue'))).data!;

    await tester.pump(const Duration(seconds: 29, milliseconds: 400));
    expect(find.text("TIME'S UP"), findsOneWidget);
    expect(find.text('IT WAS'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('reveal-reference'))).data, reference);
    expect(tester.widget<Text>(find.byKey(const Key('reveal-clue'))).data, phrase);
    expect(find.text('Lower the phone'), findsNothing);
    expect(shownScore(tester), '0');
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 500));
    expect(shownScore(tester), '1');
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.byKey(const Key('best-line')), findsOneWidget);
    expect(find.byKey(const Key('round-list')), findsOneWidget);
    expect(find.text(reference), findsNothing, reason: 'the unanswered card is not a mark');
  });

  testWidgets('time up during a got-it flash has nothing to reveal and keeps Lower the phone', (tester) async {
    await pumpGame(tester);
    await startTapRound(tester);
    await beginCard(tester);
    await tester.pump(const Duration(seconds: 29, milliseconds: 700));
    await tester.tap(find.byKey(const Key('got-it')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("TIME'S UP"), findsOneWidget);
    expect(find.text('IT WAS'), findsNothing);
    expect(find.text('Lower the phone'), findsOneWidget);
    expect(shownScore(tester), '0');
    await tester.pump(const Duration(milliseconds: 800));
    expect(shownScore(tester), '1');
  });

  testWidgets('the score counts up through the hold and the results open on the final score', (tester) async {
    await pumpGame(tester);
    await startTapRound(tester);
    await beginCard(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('got-it')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }
    await tester.pump(const Duration(seconds: 27, milliseconds: 300));
    expect(find.text("TIME'S UP"), findsOneWidget);
    expect(shownScore(tester), '0');
    await tester.pump(const Duration(milliseconds: 100));
    expect(shownScore(tester), '0');
    await tester.pump(const Duration(milliseconds: 400));
    final partway = int.parse(shownScore(tester));
    expect(partway, inInclusiveRange(1, 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(shownScore(tester), '4');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('best-line')), findsOneWidget);
    expect(find.text('BEST 4'), findsOneWidget);
  });
}

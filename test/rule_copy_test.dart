import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/deck.dart';
import 'package:scripture_up/recording/moments.dart';
import 'package:scripture_up/ui/results_view.dart';
import 'package:scripture_up/ui/round_views.dart';
import 'package:scripture_up/ui/sheets.dart';
import 'package:scripture_up/ui/style.dart';

import 'support/app_fonts.dart';

Future<void> pumpLandscape(WidgetTester tester, Widget view) async {
  await tester.binding.setSurfaceSize(const Size(812, 375));
  tester.view.physicalSize = const Size(812, 375);
  tester.view.devicePixelRatio = 1;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: scriptureTheme(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.fromLTRB(50, 0, 50, 21),
          ),
          child: Scaffold(body: view),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets('the forehead screen tells the guesser their one job', (tester) async {
    await pumpLandscape(
      tester,
      const ForeheadView(
        roundNumber: 1,
        armProgress: 0,
        tapMode: false,
        recording: true,
        onStart: _noop,
        onLeave: _noop,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.text('Your team reads you a phrase. Name the book, chapter, and verse.'),
      findsOneWidget,
    );
  });

  testWidgets('the countdown tells the team their job, and what never to say', (tester) async {
    await pumpLandscape(
      tester,
      const CountdownView(roundNumber: 1, numeral: 3, progress: 0, recording: true),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Read the phrase out loud. Give any hints.'), findsOneWidget);
    expect(find.text('NEVER SAY'), findsOneWidget);
    expect(find.text('The book, chapter, or verse.'), findsOneWidget);
  });

  testWidgets('about states the rule in two lines beside the tilt lines', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: scriptureTheme(),
        home: AboutSheet(
          respectSilence: true,
          onRespectSilence: (_) {},
          onDebug: () {},
        ),
      ),
    );
    expect(
      find.text(
        'The team reads the phrase out loud and may give any hints, but never says the book, chapter, or verse.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'The guesser names the book, chapter, and verse. The team decides if it is right.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Tilt the screen down when the guess is right. Tilt it up to pass.'),
      findsOneWidget,
    );
  });

  test('every book pitch says the same rule and none contradicts it', () {
    final pitches = [
      for (final id in ['bom', 'ot', 'nt', 'dc'])
        parseDeck(File('assets/decks/$id.json').readAsStringSync()).pitch,
      bookDeck(
        [for (final id in ['bom', 'ot', 'nt', 'dc'])
          parseDeck(File('assets/decks/$id.json').readAsStringSync())],
        'all',
      )!.pitch,
    ];
    for (final pitch in pitches) {
      expect(pitch, startsWith('Your team reads the phrase. You name the '));
      expect(pitch.toLowerCase(), isNot(contains('act')));
      expect(pitch.toLowerCase(), isNot(contains('say the reference')));
    }
  });

  testWidgets('results show a phrase as written, without a second pair of quote marks', (tester) async {
    const phrase = '“Choose you this day whom ye will serve.”';
    await pumpLandscape(
      tester,
      ResultsView(
        headline: "TIME'S UP",
        score: 0,
        deckName: 'Old Testament',
        seconds: 60,
        passed: 1,
        bestLabel: 'BEST 0',
        newBest: false,
        marks: const [
          RoundMark(
            cardId: 'ot-josh-24-15',
            prompt: 'Joshua 24:15',
            clue: phrase,
            correct: false,
            tMs: 1000,
          ),
        ],
        expanded: 0,
        hasRecording: false,
        onToggle: (_) {},
        onJump: (_) {},
        onPlayAgain: () {},
        onNewDeck: () {},
        onHome: () {},
        recording: const SizedBox.shrink(),
      ),
    );
    expect(find.text(phrase), findsOneWidget);
    expect(find.textContaining('““'), findsNothing);
  });
}

void _noop() {}

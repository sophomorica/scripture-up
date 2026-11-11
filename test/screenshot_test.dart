import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/deck.dart';
import 'package:scripture_up/recording/moments.dart';
import 'package:scripture_up/recording/recording_store.dart';
import 'package:scripture_up/ui/library_screen.dart';
import 'package:scripture_up/ui/lobby_screen.dart';
import 'package:scripture_up/ui/results_view.dart';
import 'package:scripture_up/ui/round_views.dart';
import 'package:scripture_up/ui/sheets.dart';
import 'package:scripture_up/ui/style.dart';

import 'support/app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders each screen to artifacts/screens', (tester) async {
    await loadAppFonts();
    final decks = [
      for (final path in deckAssetPaths)
        parseDeck(File(path).readAsStringSync()),
    ];
    final bom = decks.singleWhere((deck) => deck.id == 'bom');
    final dc = decks.singleWhere((deck) => deck.id == 'dc');
    GameCard cardOf(Deck deck, String id) =>
        deck.cards.singleWhere((card) => card.id == id);
    final typical = cardOf(bom, 'bom-1ne-3-7');
    final passed = cardOf(bom, 'bom-alma-34-9-10');
    final longest = cardOf(dc, 'dc-d-c-121-36-41-42');
    const landscape = Size(812, 375);
    const sensorHousing = EdgeInsets.fromLTRB(50, 0, 50, 21);
    final marks = [
      RoundMark(
        cardId: typical.id,
        prompt: typical.prompt,
        clue: typical.clue,
        correct: true,
        tMs: 4200,
      ),
      RoundMark(
        cardId: passed.id,
        prompt: passed.prompt,
        clue: passed.clue,
        correct: false,
        tMs: 9100,
      ),
    ];

    Future<void> capture(String name) async {
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('shot')),
      );
      final image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: 2),
      );
      final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.png),
      );
      final file = File('artifacts/screens/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    Future<void> shoot(
      String name,
      Size size,
      Widget child, {
      EdgeInsets padding = EdgeInsets.zero,
    }) async {
      await tester.binding.setSurfaceSize(size);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: scriptureTheme(),
          home: Scaffold(
            backgroundColor: ink,
            body: SizedBox.expand(
              child: RepaintBoundary(
                key: const Key('shot'),
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(padding: padding),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await capture(name);
    }

    await shoot(
      '01-lobby',
      const Size(402, 874),
      LobbyScreen(
        decks: decks,
        length: const Duration(seconds: 60),
        onLength: (_) {},
        onPlay: (_) {},
        onOpen: (_) {},
        onVideos: () {},
        onAbout: () {},
      ),
    );
    await tester.tap(find.byKey(const Key('book-ot')));
    await tester.pumpAndSettle();
    await capture('01-lobby-ot');
    await tester.tap(find.byKey(const Key('book-all')));
    await tester.pumpAndSettle();
    await capture('01-lobby-all');
    await tester.tap(find.byKey(const Key('deck-nt')));
    await tester.pumpAndSettle();
    await capture('01-lobby-nt-tile');
    await shoot(
      '02-deck-sheet',
      const Size(402, 874),
      DeckSheet(
        deck: bom,
        length: const Duration(seconds: 60),
        record: false,
        tapMode: false,
        onLength: (_) {},
        onRecord: (_) {},
        onTapMode: (_) {},
        onPlay: () {},
      ),
    );
    await shoot(
      '03-forehead',
      landscape,
      const ForeheadView(
        roundNumber: 1,
        armProgress: 0.65,
        tapMode: false,
        recording: true,
        onStart: _noop,
        onLeave: _noop,
      ),
      padding: sensorHousing,
    );
    await shoot(
      '04-countdown',
      landscape,
      const CountdownView(
        roundNumber: 1,
        numeral: 2,
        progress: 0.4,
        recording: true,
      ),
      padding: sensorHousing,
    );
    CardPlayView cardView(GameCard card, Deck deck, {bool tap = false}) {
      return CardPlayView(
        color: deck.hero,
        prompt: card.prompt,
        clue: card.clue,
        got: 3,
        timeLeft: const Duration(seconds: 42),
        deckName: deck.name,
        recording: false,
        tapMode: tap,
        urgent: false,
        urgentFast: false,
        pauseProgress: 0,
        onCorrect: () {},
        onPass: () {},
        onPauseDown: () {},
        onPauseUp: () {},
      );
    }

    await shoot(
      '05-card',
      landscape,
      cardView(typical, bom),
      padding: sensorHousing,
    );
    await shoot(
      '05-card-longest',
      landscape,
      cardView(longest, dc),
      padding: sensorHousing,
    );
    await shoot(
      '05-card-urgent',
      landscape,
      CardPlayView(
        color: bom.hero,
        prompt: typical.prompt,
        clue: typical.clue,
        got: 7,
        timeLeft: const Duration(milliseconds: 4100),
        deckName: bom.name,
        recording: false,
        tapMode: false,
        urgent: true,
        urgentFast: true,
        pauseProgress: 0,
        glow: 0.85,
        onCorrect: () {},
        onPass: () {},
        onPauseDown: () {},
        onPauseUp: () {},
      ),
      padding: sensorHousing,
    );
    await shoot(
      '05-card-longest-tap',
      landscape,
      cardView(longest, dc, tap: true),
      padding: sensorHousing,
    );
    await shoot(
      '06-correct',
      landscape,
      CorrectFlashView(
        prompt: typical.prompt,
        timeLeft: const Duration(seconds: 41),
        reduceMotion: false,
        progress: 0.3,
      ),
      padding: sensorHousing,
    );
    await shoot(
      '07-pass',
      landscape,
      PassFlashView(
        prompt: passed.prompt,
        timeLeft: const Duration(seconds: 37),
        progress: 0.5,
      ),
      padding: sensorHousing,
    );
    await shoot(
      '08-time-up',
      landscape,
      TimeUpView(
        headline: "TIME'S UP",
        score: 8,
        revealPrompt: typical.prompt,
        revealClue: typical.clue,
      ),
      padding: sensorHousing,
    );
    await shoot(
      '08-time-up-longest',
      landscape,
      TimeUpView(
        headline: "TIME'S UP",
        score: 12,
        revealPrompt: longest.prompt,
        revealClue: longest.clue,
      ),
      padding: sensorHousing,
    );
    await shoot(
      '08-time-up-no-card',
      landscape,
      const TimeUpView(headline: "TIME'S UP", score: 8),
      padding: sensorHousing,
    );
    await shoot(
      '09-results',
      landscape,
      ResultsView(
        headline: "TIME'S UP",
        score: 8,
        deckName: 'Book of Mormon',
        seconds: 60,
        passed: 2,
        bestLabel: 'BEST 8',
        newBest: false,
        marks: marks,
        expanded: 1,
        hasRecording: true,
        onToggle: (_) {},
        onJump: (_) {},
        onPlayAgain: () {},
        onNewDeck: () {},
        onHome: () {},
        recording: RecordingStrip(
          label: 'Round video · 1:00 · stays on this phone',
          onWatch: () {},
          onSave: () {},
          onDelete: () {},
          canSave: true,
          canDelete: true,
        ),
      ),
      padding: sensorHousing,
    );
    final libraryRoot = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('scripture-up-shots'),
    ))!;
    await shoot(
      '10-library-empty',
      const Size(402, 874),
      LibraryScreen(store: RecordingStore(libraryRoot)),
    );

    await tester.binding.setSurfaceSize(null);
    expect(File('artifacts/screens/05-card.png').existsSync(), isTrue);
    expect(File('artifacts/screens/05-card-longest.png').existsSync(), isTrue);
    expect(
      File('artifacts/screens/09-results.png').lengthSync(),
      greaterThan(1000),
    );
  });
}

void _noop() {}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders each screen to artifacts/screens', (tester) async {
    final decks = [
      for (final path in deckAssetPaths)
        parseDeck(File(path).readAsStringSync()),
    ];
    final bom = decks.singleWhere((deck) => deck.id == 'bom');
    const lapis = Color(0xFF1F4BA5);
    const marks = [
      RoundMark(
        cardId: 'bom-3ne-11-10',
        prompt: '3 Nephi 11:10',
        clue: 'He speaks his own name',
        correct: true,
        tMs: 4200,
      ),
      RoundMark(
        cardId: 'bom-alma-32-21',
        prompt: 'Alma 32:21',
        clue: 'Hope in what is not seen',
        correct: false,
        tMs: 9100,
      ),
    ];

    Future<void> shoot(String name, Size size, Widget child) async {
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
              child: RepaintBoundary(key: const Key('shot'), child: child),
            ),
          ),
        ),
      );
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
      const Size(900, 420),
      const ForeheadView(
        roundNumber: 1,
        armProgress: 0.65,
        tapMode: false,
        recording: true,
        onStart: _noop,
      ),
    );
    await shoot(
      '04-countdown',
      const Size(900, 420),
      const CountdownView(
        roundNumber: 1,
        numeral: 2,
        progress: 0.4,
        recording: true,
      ),
    );
    await shoot(
      '05-card',
      const Size(900, 420),
      CardPlayView(
        color: lapis,
        prompt: '3 Nephi 11:10',
        clue: 'He speaks his own name',
        got: 3,
        timeLeft: const Duration(seconds: 42),
        deckName: 'Book of Mormon',
        recording: false,
        tapMode: false,
        urgent: false,
        urgentFast: false,
        pauseProgress: 0,
        onCorrect: () {},
        onPass: () {},
        onPauseDown: () {},
        onPauseUp: () {},
      ),
    );
    await shoot(
      '06-correct',
      const Size(900, 420),
      const CorrectFlashView(
        prompt: '3 Nephi 11:10',
        timeLeft: Duration(seconds: 41),
        reduceMotion: false,
      ),
    );
    await shoot(
      '07-pass',
      const Size(900, 420),
      const PassFlashView(
        prompt: 'Alma 32:21',
        timeLeft: Duration(seconds: 37),
      ),
    );
    await shoot(
      '08-time-up',
      const Size(900, 420),
      const TimeUpView(headline: "TIME'S UP", score: 8),
    );
    await shoot(
      '09-results',
      const Size(900, 420),
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
    expect(File('artifacts/screens/09-results.png').lengthSync(), greaterThan(1000));
  });
}

void _noop() {}

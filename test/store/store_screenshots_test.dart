// App Store screenshots at the exact sizes App Store Connect takes.
// Off by default. Run:
//   STORE_SHOTS=1 flutter test test/store/store_screenshots_test.dart
// Writes docs/store/screenshots/<device>/NN-name.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/deck.dart';
import 'package:scripture_up/recording/moments.dart';
import 'package:scripture_up/ui/lobby_screen.dart';
import 'package:scripture_up/ui/results_view.dart';
import 'package:scripture_up/ui/round_views.dart';
import 'package:scripture_up/ui/sheets.dart';
import 'package:scripture_up/ui/style.dart';

import '../support/app_fonts.dart';

class StoreDevice {
  const StoreDevice(this.dir, this.portrait, this.ratio, this.portraitPad, this.landscapePad);

  final String dir;

  /// Logical portrait size. Pixels = this × [ratio].
  final Size portrait;
  final double ratio;
  final EdgeInsets portraitPad;
  final EdgeInsets landscapePad;

  Size get landscape => Size(portrait.height, portrait.width);
}

/// 6.9" iPhone (1320 × 2868) and 13" iPad (2064 × 2752), App Store Connect's
/// required sizes for an app that runs on iPhone and iPad.
const devices = [
  StoreDevice(
    'iphone-6.9',
    Size(440, 956),
    3,
    EdgeInsets.fromLTRB(0, 62, 0, 34),
    EdgeInsets.fromLTRB(62, 0, 62, 21),
  ),
  StoreDevice(
    'ipad-13',
    Size(1032, 1376),
    2,
    EdgeInsets.fromLTRB(0, 24, 0, 20),
    EdgeInsets.fromLTRB(0, 24, 0, 20),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'renders App Store screenshots to docs/store/screenshots',
    skip: Platform.environment['STORE_SHOTS'] == null,
    (tester) async {
      await loadAppFonts();
      final decks = [
        for (final path in deckAssetPaths) parseDeck(File(path).readAsStringSync()),
      ];
      final bom = decks.singleWhere((deck) => deck.id == 'bom');
      GameCard cardOf(Deck deck, String id) => deck.cards.singleWhere((card) => card.id == id);
      final typical = cardOf(bom, 'bom-1ne-3-7');
      final passed = cardOf(bom, 'bom-alma-34-9-10');
      final marks = [
        RoundMark(cardId: typical.id, prompt: typical.prompt, clue: typical.clue, correct: true, tMs: 4200),
        RoundMark(cardId: passed.id, prompt: passed.prompt, clue: passed.clue, correct: false, tMs: 9100),
      ];

      for (final device in devices) {
        Future<void> shoot(String name, Widget child, {bool landscape = false}) async {
          final logical = landscape ? device.landscape : device.portrait;
          await tester.binding.setSurfaceSize(logical);
          tester.view.physicalSize = logical * device.ratio;
          tester.view.devicePixelRatio = device.ratio;
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
                        data: MediaQuery.of(context).copyWith(
                          padding: landscape ? device.landscapePad : device.portraitPad,
                          size: logical,
                          devicePixelRatio: device.ratio,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${device.dir}/$name');
          final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
          final image = await tester.runAsync(() => boundary.toImage(pixelRatio: device.ratio));
          final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
          final file = File('docs/store/screenshots/${device.dir}/$name.png');
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(bytes!.buffer.asUint8List());
        }

        await shoot(
          '01-lobby',
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
          '02-card',
          CardPlayView(
            color: bom.hero,
            prompt: typical.prompt,
            clue: typical.clue,
            got: 3,
            timeLeft: const Duration(seconds: 42),
            deckName: bom.name,
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
          landscape: true,
        );
        await shoot(
          '03-correct',
          CorrectFlashView(
            prompt: typical.prompt,
            timeLeft: const Duration(seconds: 41),
            reduceMotion: true,
            progress: 0.3,
          ),
          landscape: true,
        );
        await shoot(
          '04-deck-sheet',
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
          '05-results',
          ResultsView(
            headline: "TIME'S UP",
            score: 8,
            deckName: bom.name,
            seconds: 60,
            passed: 2,
            bestLabel: 'BEST 8',
            newBest: true,
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
          landscape: true,
        );
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}

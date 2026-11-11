import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/deck.dart';
import 'package:scripture_up/ui/draw.dart';
import 'package:scripture_up/ui/lobby_screen.dart';
import 'package:scripture_up/ui/style.dart';

import 'support/app_fonts.dart';
import 'widget_test.dart' show loadDecks;

Future<void> pumpLobby(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
}) async {
  final size = Size(width, 5000);
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: scriptureTheme(),
      home: LobbyScreen(
        decks: loadDecks(),
        length: const Duration(seconds: 60),
        onLength: (_) {},
        onPlay: (_) {},
        onOpen: (_) {},
        onVideos: () {},
        onAbout: () {},
      ),
    ),
  );
  await tester.pump();
}

Finder inTile(String id, Finder matching) {
  return find.descendant(of: find.byKey(Key('deck-$id')), matching: matching);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final width in [375.0, 390.0]) {
    testWidgets('canon tiles show the whole book name at ${width.toInt()} wide', (tester) async {
      await pumpLobby(tester, width: width);
      expect(tester.takeException(), isNull);
      for (final name in ['Doctrine and Covenants', 'Old Testament', 'New Testament']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byType(InkWell),
            matching: find.text(name),
          ),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: name);
        final lines = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: name.length),
        );
        expect(lines, isNotEmpty, reason: name);
      }
    });
  }

  testWidgets('the lobby lays out without overflow at 375 and 390 wide', (tester) async {
    for (final width in [375.0, 390.0]) {
      await pumpLobby(tester, width: width);
      expect(tester.takeException(), isNull, reason: '$width');
    }
  });

  testWidgets('the lobby lays out without overflow at 320 wide with text scale 2.0', (tester) async {
    await pumpLobby(tester, width: 320, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('deck-hard')), findsOneWidget);
    expect(find.byKey(const Key('length-90')), findsOneWidget);
  });

  testWidgets('party tiles say coming soon, canon tiles keep their card count', (tester) async {
    await pumpLobby(tester, width: 390);
    final decks = loadDecks();
    expect(find.text('PARTY DECKS'), findsOneWidget);
    expect(find.text('next up'), findsOneWidget);
    expect(find.text('new'), findsNothing);
    for (final id in partyDeckIds) {
      expect(decks.singleWhere((deck) => deck.id == id).playable, isFalse, reason: id);
      expect(inTile(id, find.text('COMING SOON')), findsOneWidget, reason: id);
      expect(inTile(id, find.textContaining('CARDS')), findsNothing, reason: id);
      expect(inTile(id, find.text('NEW')), findsNothing, reason: id);
      expect(inTile(id, find.byType(Hatch)), findsOneWidget, reason: id);
    }
    for (final id in canonDeckIds) {
      final cards = decks.singleWhere((deck) => deck.id == id).cardCount;
      expect(inTile(id, find.text('$cards CARDS')), findsOneWidget, reason: id);
      expect(inTile(id, find.text('COMING SOON')), findsNothing, reason: id);
      expect(inTile(id, find.byType(Hatch)), findsNothing, reason: id);
    }
  });
}

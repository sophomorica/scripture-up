import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/app.dart';
import 'package:scripture_up/feedback/game_audio.dart';
import 'package:scripture_up/feedback/game_haptics.dart';
import 'package:scripture_up/game/deck.dart';
import 'package:scripture_up/game/tilt_sensor.dart';

import 'support/fake_recorder.dart';

List<Deck> loadDecks() {
  return [
    for (final path in deckAssetPaths) parseDeck(File(path).readAsStringSync()),
  ];
}

Future<Directory> pumpGame(
  WidgetTester tester, {
  bool failCamera = false,
}) async {
  final directory = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('scripture-up-ui'),
  ))!;
  await tester.binding.setSurfaceSize(const Size(402, 874));
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final origin = tester.binding.clock.now();
  await tester.pumpWidget(
    ScriptureUpApp(
      documentsDirectory: directory,
      decks: loadDecks(),
      sensor: ScriptedTiltSensor(const Stream<AccelSample>.empty()),
      audio: SilentAudio(),
      haptics: SilentHaptics(),
      recorderFactory: () => FakeRoundRecorder(directory, fail: failCamera),
      clock: () => DateTime(2026, 9, 23, 22, 49, 55, 10),
      elapsed: () => tester.binding.clock.now().difference(origin),
      random: () => Random(1),
    ),
  );
  await tester.pump();
  return directory;
}

Future<void> flushIo(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
  });
  await tester.pump();
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('play-hero')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> startTapRound(WidgetTester tester, {bool record = false}) async {
  await tester.tap(find.byKey(const Key('length-30')));
  await tester.pump();
  await openSheet(tester);
  if (record) {
    await tester.tap(find.byKey(const Key('record-team')));
    await tester.pump();
  }
  await tester.tap(find.text('Tap buttons'));
  await tester.pump();
  await tester.binding.setSurfaceSize(const Size(900, 420));
  tester.view.physicalSize = const Size(900, 420);
  await tester.pump();
  await tester.tap(find.byKey(const Key('sheet-play')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> beginCard(WidgetTester tester) async {
  expect(find.text('ROUND 1'), findsOneWidget);
  await tester.tap(find.byKey(const Key('start-round')));
  await tester.pump();
  expect(find.byKey(const Key('countdown')), findsOneWidget);
  expect(find.text('3'), findsWidgets);
  await tester.pump(const Duration(milliseconds: 2700));
  expect(find.byKey(const Key('card-reference')), findsOneWidget);
}

Future<void> finishFromCard(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 31));
  expect(find.text("TIME'S UP"), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 1600));
  expect(find.byKey(const Key('best-line')), findsOneWidget);
}

void main() {
  testWidgets('lobby is deck-first and keeps closed decks closed', (tester) async {
    await pumpGame(tester);
    expect(find.text('Book of Mormon'), findsOneWidget);
    expect(find.text('18 CARDS · REFERENCE + CLUE'), findsOneWidget);
    expect(find.text('NARROW ROAD STUDIOS'), findsOneWidget);
    expect(find.text('COMING SOON'), findsNWidgets(3));
    expect(
      find.text('Not affiliated with The Church of Jesus Christ of Latter-day Saints.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('deck-dc')));
    await tester.pump();
    expect(find.text('Coming soon. Book of Mormon is live.'), findsOneWidget);
    expect(find.byKey(const Key('play-hero')), findsOneWidget);

    final people = find.byKey(const Key('deck-people'));
    for (var i = 0; i < 8 && people.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(find.byKey(const Key('lobby-scroll')), const Offset(0, -280));
      await tester.pump();
    }
    await tester.tap(people);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('not live yet'), findsOneWidget);
    expect(find.byKey(const Key('sheet-play')), findsNothing);
  });

  testWidgets('about keeps the affiliation line and can show tilt', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.byKey(const Key('about')));
    await tester.pump();
    expect(
      find.text('Not affiliated with The Church of Jesus Christ of Latter-day Saints.'),
      findsOneWidget,
    );
    await tester.longPress(find.text('Scripture Up'));
    await tester.pump();
    expect(find.byKey(const Key('tilt-debug')), findsOneWidget);
    expect(find.byKey(const Key('respect-silence')), findsOneWidget);
  });

  testWidgets('a tap round scores, passes, and keeps a personal best', (tester) async {
    await pumpGame(tester);
    await startTapRound(tester);
    await beginCard(tester);
    final first = tester.widget<Text>(find.byKey(const Key('card-reference'))).data!;
    final clue = tester.widget<Text>(find.byKey(const Key('card-clue'))).data!;
    expect(clue.trim(), isNotEmpty);

    await tester.pump(const Duration(seconds: 31));
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text("TIME'S UP"), findsOneWidget);
    expect(find.text('BEST 0'), findsOneWidget);
    expect(find.byKey(const Key('play-again')), findsOneWidget);
    expect(find.byKey(const Key('new-deck')), findsOneWidget);
    expect(find.byKey(const Key('home-results')), findsOneWidget);
    await flushIo(tester);

    await tester.tap(find.byKey(const Key('play-again')));
    await tester.pump();
    await flushIo(tester);
    expect(find.text('ROUND 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start-round')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2700));
    final second = tester.widget<Text>(find.byKey(const Key('card-reference'))).data!;
    expect(second, isNotEmpty);
    await tester.tap(find.byKey(const Key('got-it')));
    await tester.pump();
    expect(find.text('Got it!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    final after = tester.widget<Text>(find.byKey(const Key('card-reference'))).data!;
    expect(after, isNot(second));
    await tester.tap(find.byKey(const Key('pass')));
    await tester.pump();
    expect(find.text('PASS'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('card-reference')), findsOneWidget);

    await finishFromCard(tester);
    expect(find.text('NEW BEST'), findsOneWidget);
    expect(find.byKey(const Key('round-list')), findsOneWidget);
    expect(find.textContaining(second), findsWidgets);
    expect(first, isNotEmpty);
  });

  testWidgets('long-press on the clock ends the round', (tester) async {
    await pumpGame(tester);
    await startTapRound(tester);
    await beginCard(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('round-clock'))),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await gesture.up();
    await tester.pump();
    expect(find.text('PAUSED'), findsOneWidget);
    await tester.tap(find.byKey(const Key('end-round')));
    await tester.pump();
    expect(find.text('ENDED'), findsOneWidget);
  });

  testWidgets('a failed camera still plays and says so', (tester) async {
    await pumpGame(tester, failCamera: true);
    await startTapRound(tester, record: true);
    await beginCard(tester);
    await tester.tap(find.byKey(const Key('got-it')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await finishFromCard(tester);
    await flushIo(tester);
    expect(find.textContaining('still plays'), findsOneWidget);
    expect(find.byKey(const Key('save-recording')), findsNothing);
  });

  testWidgets('save, jump, and delete stay on this phone', (tester) async {
    final directory = await pumpGame(tester);
    await startTapRound(tester, record: true);
    await beginCard(tester);
    await tester.tap(find.byKey(const Key('pass')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await finishFromCard(tester);
    await flushIo(tester);

    expect(find.byKey(const Key('save-recording')), findsOneWidget);
    await tester.tap(find.text('TAP').first);
    await tester.pump();
    await tester.ensureVisible(find.textContaining('▶'));
    await tester.tap(find.textContaining('▶'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('DONE'), findsOneWidget);
    expect(find.byKey(const Key('seek-unavailable')), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('DONE'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('save-recording')));
    await tester.tap(find.byKey(const Key('save-recording')));
    await flushIo(tester);
    expect(find.text('Saved on this phone'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-results')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.binding.setSurfaceSize(const Size(402, 874));
    tester.view.physicalSize = const Size(402, 874);
    await tester.pump();
    expect(find.byKey(const Key('play-hero')), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-recordings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Sep 23, 2026 · 10:49 PM'), findsOneWidget);
    final saved = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'));
    expect(saved, isNotEmpty);

    await tester.tap(find.byKey(const Key('delete-saved-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-delete-saved')));
    await flushIo(tester);
    expect(find.byKey(const Key('library-empty')), findsOneWidget);
  });

  testWidgets('leaving with an unsaved clip asks before it deletes', (tester) async {
    await pumpGame(tester);
    await startTapRound(tester, record: true);
    await beginCard(tester);
    await finishFromCard(tester);
    await flushIo(tester);
    await tester.tap(find.byKey(const Key('new-deck')));
    await tester.pump();
    expect(find.text('Keep this video?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.binding.setSurfaceSize(const Size(402, 874));
    tester.view.physicalSize = const Size(402, 874);
    await tester.pump();
    expect(find.byKey(const Key('play-hero')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-recordings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('library-empty')), findsOneWidget);
  });
}

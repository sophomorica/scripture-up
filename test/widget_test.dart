import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/app.dart';
import 'package:scripture_up/game/tilt.dart';

import 'support/fake_recorder.dart';

Future<Directory> pumpGame(
  WidgetTester tester, {
  bool failCamera = false,
}) async {
  final directory = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('scripture-up-ui'),
  ))!;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScriptureUpApp(
      documentsDirectory: directory,
      recorderFactory: () => FakeRoundRecorder(directory, fail: failCamera),
      tiltReadings: const Stream<TiltReading>.empty(),
      lengths: const [Duration(seconds: 2)],
      countdown: const Duration(seconds: 1),
      random: () => Random(1),
      clock: () => DateTime(2026, 9, 23, 22, 49, 55),
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

Future<void> finishRound(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const Key('countdown')), findsOneWidget);
  await tester.tap(find.byKey(const Key('got-it')));
  await tester.pump();
  expect(find.byKey(const Key('countdown')), findsOneWidget);

  await tester.pump(const Duration(seconds: 1));
  final reference = tester
      .widget<Text>(find.byKey(const Key('card-reference')))
      .data!;
  final clue = tester.widget<Text>(find.byKey(const Key('card-clue'))).data!;
  expect(clue.trim(), isNotEmpty);
  expect(find.text('0:02'), findsOneWidget);

  await tester.tap(find.byKey(const Key('got-it')));
  await tester.pump();
  final next = tester
      .widget<Text>(find.byKey(const Key('card-reference')))
      .data!;
  expect(next, isNot(reference));

  await tester.tap(find.byKey(const Key('pass')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await flushIo(tester);

  expect(find.byKey(const Key('got-list')), findsOneWidget);
  expect(
    find.descendant(
      of: find.byKey(const Key('got-list')),
      matching: find.text(reference),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: find.byKey(const Key('passed-list')),
      matching: find.text(next),
    ),
    findsOneWidget,
  );
}

void main() {
  testWidgets('home offers Book of Mormon and keeps the other decks closed', (
    tester,
  ) async {
    final directory = await pumpGame(tester);
    expect(find.text('Scripture Up'), findsOneWidget);
    expect(find.text('18 cards'), findsOneWidget);
    expect(find.text('Coming soon', skipOffstage: false), findsNWidgets(3));
    await tester.scrollUntilVisible(
      find.text(
        'Not affiliated with The Church of Jesus Christ of Latter-day Saints.',
      ),
      200,
    );
    expect(
      find.text(
        'Not affiliated with The Church of Jesus Christ of Latter-day Saints.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const Key('deck-doctrineAndCovenants')),
    );
    await tester.tap(find.byKey(const Key('deck-doctrineAndCovenants')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('That deck is on the way.'), findsOneWidget);
    expect(find.byKey(const Key('countdown')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('open-recordings')));
    await tester.tap(find.byKey(const Key('open-recordings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Saved clips show up here after you keep a round.'),
      findsOneWidget,
    );

    await tester.runAsync(() => directory.delete(recursive: true));
  });

  testWidgets('a round scores guesses and save keeps a local clip', (
    tester,
  ) async {
    final directory = await pumpGame(tester);
    await tester.ensureVisible(find.byKey(const Key('deck-bookOfMormon')));
    await tester.tap(find.byKey(const Key('deck-bookOfMormon')));
    await tester.pump();
    await finishRound(tester);

    expect(find.text('1'), findsWidgets);
    await tester.tap(find.byKey(const Key('save-recording')));
    await flushIo(tester);
    expect(find.text('Saved on this phone'), findsOneWidget);

    final saved = Directory('${directory.path}/recordings')
        .listSync()
        .whereType<File>()
        .toList();
    expect(saved, hasLength(1));
    expect(await tester.runAsync(() => saved.single.readAsBytes()), [
      7,
      7,
      7,
      7,
    ]);

    await tester.tap(find.byKey(const Key('change-deck')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('open-recordings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Sep 23, 2026 · 10:49 PM'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-saved-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('confirm-delete-saved')));
    await tester.pump();
    expect(
      find.text('Saved clips show up here after you keep a round.'),
      findsOneWidget,
    );
    expect(await tester.runAsync(() => saved.single.exists()), isFalse);

    await tester.runAsync(() => directory.delete(recursive: true));
  });

  testWidgets('delete wipes the round clip and a denied camera still plays', (
    tester,
  ) async {
    final directory = await pumpGame(tester);
    await tester.ensureVisible(find.byKey(const Key('deck-bookOfMormon')));
    await tester.tap(find.byKey(const Key('deck-bookOfMormon')));
    await tester.pump();
    await finishRound(tester);

    await tester.tap(find.byKey(const Key('delete-recording')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pump();
    expect(find.text('Recording deleted'), findsOneWidget);
    final leftovers = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.mp4'));
    expect(leftovers, isEmpty);

    await tester.tap(find.byKey(const Key('play-again')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('countdown')), findsOneWidget);
    await tester.tap(find.byKey(const Key('end-round')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.runAsync(() => directory.delete(recursive: true));
  });

  testWidgets('the round still finishes when the camera cannot start', (
    tester,
  ) async {
    final directory = await pumpGame(tester, failCamera: true);
    await tester.ensureVisible(find.byKey(const Key('deck-bookOfMormon')));
    await tester.tap(find.byKey(const Key('deck-bookOfMormon')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Not recording'), findsOneWidget);

    await finishRound(tester);
    expect(
      find.text('Camera could not start. The round still plays.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('save-recording')), findsNothing);

    await tester.runAsync(() => directory.delete(recursive: true));
  });
}

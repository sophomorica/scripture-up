import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/deck.dart';

import 'support/fake_recorder.dart';
import 'support/fake_wake.dart';
import 'widget_test.dart'
    show
        beginCard,
        finishFromCard,
        flushIo,
        loadDecks,
        pumpGame,
        startTapRound;

List<Deck> bomWithCards(int count) {
  return [
    for (final deck in loadDecks())
      if (deck.id == 'bom')
        Deck(
          id: deck.id,
          name: deck.name,
          pitch: deck.pitch,
          hero: deck.hero,
          emblem: deck.emblem,
          format: deck.format,
          status: deck.status,
          cards: deck.cards.take(count).toList(),
        )
      else
        deck,
  ];
}

String clockText(WidgetTester tester) {
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const Key('round-clock')),
          matching: find.byType(Text),
        ),
      )
      .data!;
}

Future<void> startCountdown(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('start-round')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2700));
  expect(find.byKey(const Key('card-reference')), findsOneWidget);
}

Future<List<String>> passCards(WidgetTester tester, int count) async {
  final prompts = <String>[];
  for (var i = 0; i < count; i++) {
    prompts.add(tester.widget<Text>(find.byKey(const Key('card-reference'))).data!);
    await tester.tap(find.byKey(const Key('pass')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }
  return prompts;
}

Future<void> endRoundFromPause(WidgetTester tester) async {
  final press = await tester.startGesture(
    tester.getCenter(find.byKey(const Key('round-clock'))),
  );
  await tester.pump(const Duration(milliseconds: 800));
  await press.up();
  await tester.pump();
  await tester.tap(find.byKey(const Key('end-round')));
  await tester.pump();
  expect(find.byKey(const Key('play-again')), findsOneWidget);
}

Future<void> playRound(WidgetTester tester, int cards) async {
  await startCountdown(tester);
  await passCards(tester, cards);
  await endRoundFromPause(tester);
}

Future<void> backToPortrait(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(402, 874));
  tester.view.physicalSize = const Size(402, 874);
  await tester.pump();
}

List<File> recordingFiles(Directory directory) {
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.contains('/recordings/'))
      .toList();
}

List<File> keptClips(Directory directory) {
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (file) => file.path.contains('/recordings/') && file.path.endsWith('.mp4'),
      )
      .toList();
}

Future<void> recordedResults(WidgetTester tester) async {
  await startTapRound(tester, record: true);
  await beginCard(tester);
  await finishFromCard(tester);
  await flushIo(tester);
}

void main() {
  testWidgets('the round holds the screen awake from the first frame and lets go on leaving', (
    tester,
  ) async {
    final wake = FakeScreenWake();
    await pumpGame(tester, wake: wake);
    expect(wake.events, isEmpty);

    await startTapRound(tester);
    expect(wake.events, ['hold']);
    await beginCard(tester);
    await finishFromCard(tester);
    await tester.tap(find.byKey(const Key('play-again')));
    await tester.pump();
    await flushIo(tester);
    expect(find.text('ROUND 2'), findsOneWidget);
    expect(wake.events, ['hold']);

    await tester.tap(find.byKey(const Key('leave-round')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(wake.events, ['hold', 'release']);
  });

  testWidgets('the forehead screen has a close control that returns to the lobby', (tester) async {
    await pumpGame(tester);
    await startTapRound(tester);
    expect(find.text('ROUND 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('leave-round')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await backToPortrait(tester);
    expect(find.byKey(const Key('play-hero')), findsOneWidget);
    expect(find.text('ROUND 1'), findsNothing);
  });

  testWidgets('a call or Control Center pauses the card and returning does not jump the clock', (
    tester,
  ) async {
    await pumpGame(tester);
    await startTapRound(tester);
    await beginCard(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(clockText(tester), '0:27');

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.pump(const Duration(seconds: 45));
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(find.text("TIME'S UP"), findsNothing);
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(clockText(tester), '0:27');
    await tester.pump(const Duration(seconds: 1));
    expect(clockText(tester), '0:26');
  });

  testWidgets('leaving the app during the countdown returns to the forehead screen', (tester) async {
    await pumpGame(tester);
    await startTapRound(tester);
    await tester.tap(find.byKey(const Key('start-round')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byKey(const Key('countdown')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.byKey(const Key('countdown')), findsNothing);
    expect(find.byKey(const Key('card-reference')), findsNothing);
    expect(find.byKey(const Key('start-round')), findsOneWidget);

    await startCountdown(tester);
    expect(clockText(tester), '0:30');
  });

  testWidgets('play again deals cards this session has not shown before it repeats any', (tester) async {
    await pumpGame(tester);
    await startTapRound(tester);
    final first = await (() async {
      await startCountdown(tester);
      final prompts = await passCards(tester, 6);
      await endRoundFromPause(tester);
      return prompts;
    })();

    final rounds = [first];
    for (var round = 2; round <= 4; round++) {
      await tester.tap(find.byKey(const Key('play-again')));
      await tester.pump();
      await flushIo(tester);
      expect(find.text('ROUND $round'), findsOneWidget);
      await startCountdown(tester);
      rounds.add(await passCards(tester, 6));
      await endRoundFromPause(tester);
    }

    final dealt = rounds.expand((prompts) => prompts).toList();
    expect(dealt, hasLength(24));
    expect(dealt.toSet(), hasLength(24), reason: 'four rounds of six cover the 24-card deck once');
  });

  testWidgets('once every card has been shown the next rounds start a fresh pass', (tester) async {
    await pumpGame(tester, decks: bomWithCards(4));
    await startTapRound(tester);
    await startCountdown(tester);
    final cleared = await passCards(tester, 4);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('DECK CLEARED'), findsOneWidget);
    expect(cleared.toSet(), hasLength(4));

    await tester.tap(find.byKey(const Key('play-again')));
    await tester.pump();
    await flushIo(tester);
    await startCountdown(tester);
    final second = await passCards(tester, 1);
    await endRoundFromPause(tester);

    await tester.tap(find.byKey(const Key('play-again')));
    await tester.pump();
    await flushIo(tester);
    await startCountdown(tester);
    final third = await passCards(tester, 3);
    expect(third, isNot(contains(second.single)));
    expect(third.toSet(), hasLength(3));
  });

  testWidgets('play again asks before it drops an unsaved clip and keeps it on yes', (tester) async {
    final directory = await pumpGame(tester);
    await recordedResults(tester);
    expect(keptClips(directory), isEmpty);

    await tester.tap(find.byKey(const Key('play-again')));
    await tester.pump();
    expect(find.text('Keep this video?'), findsOneWidget);
    expect(find.byKey(const Key('best-line')), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-save')));
    await flushIo(tester);
    expect(find.text('ROUND 2'), findsOneWidget);
    expect(keptClips(directory), hasLength(1));
  });

  testWidgets('play again can drop the clip, and dismissing the prompt stays on results', (tester) async {
    final directory = await pumpGame(tester);
    await recordedResults(tester);

    await tester.tap(find.byKey(const Key('play-again')));
    await tester.pump();
    expect(find.text('Keep this video?'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await flushIo(tester);
    expect(find.text('Keep this video?'), findsNothing);
    expect(find.byKey(const Key('best-line')), findsOneWidget);
    expect(find.byKey(const Key('save-recording')), findsOneWidget);

    await tester.tap(find.byKey(const Key('play-again')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await flushIo(tester);
    expect(find.text('ROUND 2'), findsOneWidget);
    expect(keptClips(directory), isEmpty);
    expect(
      directory.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.mp4')),
      isEmpty,
      reason: 'the dropped clip leaves no temp file behind',
    );
  });

  testWidgets('leaving while the clip is still finalizing waits, then asks', (tester) async {
    final stopGate = Completer<void>();
    final directory = await pumpGame(
      tester,
      recorder: (dir) => FakeRoundRecorder(dir, stopGate: stopGate),
    );
    await recordedResults(tester);
    expect(find.text('Starting the camera…'), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-deck')));
    await tester.pump();
    expect(find.text('Keep this video?'), findsNothing);
    expect(find.byKey(const Key('best-line')), findsOneWidget);

    stopGate.complete();
    await flushIo(tester);
    expect(find.text('Keep this video?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-save')));
    await flushIo(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await backToPortrait(tester);
    expect(find.byKey(const Key('play-hero')), findsOneWidget);
    expect(keptClips(directory), hasLength(1));
  });

  testWidgets('a double tap on play again starts one round and asks once', (tester) async {
    final stopGate = Completer<void>();
    await pumpGame(
      tester,
      recorder: (dir) => FakeRoundRecorder(dir, stopGate: stopGate),
    );
    await recordedResults(tester);

    await tester.tap(find.byKey(const Key('play-again')));
    await tester.tap(find.byKey(const Key('play-again')));
    await tester.pump();
    stopGate.complete();
    await flushIo(tester);
    expect(find.text('Keep this video?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-delete')));
    await flushIo(tester);
    expect(find.text('ROUND 2'), findsOneWidget);
    expect(find.text('ROUND 3'), findsNothing);
  });

  testWidgets('the screen closing while play again waits for the clip does not throw', (tester) async {
    final stopGate = Completer<void>();
    await pumpGame(
      tester,
      recorder: (dir) => FakeRoundRecorder(dir, stopGate: stopGate),
    );
    await recordedResults(tester);

    await tester.tap(find.byKey(const Key('play-again')));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('play-again')), findsNothing);
    stopGate.complete();
    await flushIo(tester);
    await flushIo(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review marks are timed from when the video really started', (tester) async {
    final gate = Completer<void>();
    final directory = await pumpGame(
      tester,
      recorder: (dir) => FakeRoundRecorder(dir, gate: gate),
    );
    await startTapRound(tester, record: true);
    await tester.tap(find.byKey(const Key('start-round')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(const Key('card-reference')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pass')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await finishFromCard(tester);
    await flushIo(tester);

    await tester.ensureVisible(find.byKey(const Key('save-recording')));
    await tester.tap(find.byKey(const Key('save-recording')));
    await flushIo(tester);
    final sidecar = directory
        .listSync(recursive: true)
        .whereType<File>()
        .singleWhere(
          (file) => file.path.contains('/recordings/') && file.path.endsWith('.json'),
        );
    final marks =
        (jsonDecode(sidecar.readAsStringSync()) as Map<String, Object?>)['marks']! as List<Object?>;
    expect(marks, hasLength(1));
    expect((marks.single! as Map<String, Object?>)['tMs'], 1200);
  });

  testWidgets('deleting a saved clip from the results strip removes its marks file too', (tester) async {
    final directory = await pumpGame(tester);
    await recordedResults(tester);

    await tester.ensureVisible(find.byKey(const Key('save-recording')));
    await tester.tap(find.byKey(const Key('save-recording')));
    await flushIo(tester);
    expect(find.text('Saved on this phone'), findsOneWidget);
    expect(recordingFiles(directory).map((file) => file.path.split('.').last).toSet(), {'mp4', 'json'});

    await tester.tap(find.byKey(const Key('delete-recording')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await flushIo(tester);
    expect(find.text('Recording deleted'), findsOneWidget);
    expect(recordingFiles(directory), isEmpty);
  });
}

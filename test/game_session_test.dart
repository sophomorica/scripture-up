import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/game_session.dart';
import 'package:scripture_up/game/round_engine.dart';
import 'package:scripture_up/game/scripture_card.dart';
import 'package:scripture_up/game/tilt.dart';
import 'package:scripture_up/recording/recording_store.dart';

import 'support/fake_recorder.dart';

const cards = [
  ScriptureCard(id: 'a', reference: 'Ref A', clue: 'Clue A'),
  ScriptureCard(id: 'b', reference: 'Ref B', clue: 'Clue B'),
  ScriptureCard(id: 'c', reference: 'Ref C', clue: 'Clue C'),
];

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('scripture-up-session');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  GameSession sessionWith({
    bool fail = false,
    Completer<void>? gate,
    Stream<TiltReading>? tilt,
    Duration countdown = Duration.zero,
  }) {
    return GameSession(
      cards: cards,
      length: const Duration(seconds: 5),
      recorderFactory: () => FakeRoundRecorder(root, fail: fail, gate: gate),
      store: RecordingStore(root),
      tilt: tilt,
      random: Random(1),
      clock: () => DateTime(2026, 9, 23, 22, 49, 55, 10),
      countdown: countdown,
      driveClock: false,
    );
  }

  test(
    'a correct guess and a pass survive a camera that never starts',
    () async {
      final session = sessionWith(fail: true);
      await session.start();
      await Future<void>.delayed(Duration.zero);
      session.markCorrect();
      session.markPass();
      final playing = session.phase! as RoundPlaying;
      expect(playing.correct.single.reference, isNotEmpty);
      expect(playing.passed, hasLength(1));
      expect(
        playing.correct.single.reference,
        isNot(playing.passed.single.reference),
      );

      session.elapse(const Duration(seconds: 5));
      await session.sealRecording();
      expect(session.phase, isA<RoundFinished>());
      expect(session.clip, isA<ClipUnavailable>());
      expect((session.clip as ClipUnavailable).reason, contains('still plays'));
      session.dispose();
    },
  );

  test('save keeps the clip and delete wipes it', () async {
    final session = sessionWith();
    await session.start();
    session.elapse(const Duration(seconds: 5));
    await session.sealRecording();
    final pending = session.clip as ClipPending;
    expect(await pending.file.readAsBytes(), [7, 7, 7, 7]);

    await session.saveRecording();
    final saved = session.clip as ClipSaved;
    expect(await pending.file.exists(), isFalse);
    expect(await saved.file.readAsBytes(), [7, 7, 7, 7]);
    expect(
      saved.file.path,
      contains('recordings/round-20260923-224955-010.mp4'),
    );

    await session.deleteRecording();
    expect(session.clip, isA<ClipDeleted>());
    expect(await saved.file.exists(), isFalse);
    session.dispose();
  });

  test('leaving before the camera is ready wipes the clip', () async {
    final gate = Completer<void>();
    final session = sessionWith(gate: gate);
    await session.start();
    final leaving = session.leaveRound();
    gate.complete();
    await leaving;
    expect(session.clip, isA<ClipDeleted>());
    final leftovers = root.listSync().whereType<File>();
    expect(leftovers, isEmpty);
    session.dispose();
  });

  test('tilt scores only after the phone returns upright', () async {
    final tilt = StreamController<TiltReading>(sync: true);
    final session = sessionWith(
      tilt: tilt.stream,
      countdown: const Duration(seconds: 3),
    );
    await session.start();

    for (var i = 0; i < 3; i++) {
      tilt.add(const TiltReading(y: 6, z: -7.8));
    }
    expect(session.phase, isA<RoundCountdown>());

    session.elapse(const Duration(seconds: 3));
    expect(session.phase, isA<RoundPlaying>());
    final first = (session.phase! as RoundPlaying).current.id;

    for (var i = 0; i < 3; i++) {
      tilt.add(const TiltReading(y: 6, z: -7.8));
    }
    expect((session.phase! as RoundPlaying).current.id, first);
    expect((session.phase! as RoundPlaying).correct, isEmpty);

    tilt.add(const TiltReading(y: 9.8, z: 0));
    for (var i = 0; i < 3; i++) {
      tilt.add(const TiltReading(y: 6, z: -7.8));
    }
    final playing = session.phase! as RoundPlaying;
    expect(playing.correct, hasLength(1));
    expect(playing.current.id, isNot(first));

    await tilt.close();
    session.dispose();
  });
}

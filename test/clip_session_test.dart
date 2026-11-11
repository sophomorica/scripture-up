import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/recording/clip_session.dart';
import 'package:scripture_up/recording/moments.dart';
import 'package:scripture_up/recording/recording_store.dart';

import 'support/fake_recorder.dart';

void main() {
  late Directory root;
  var roundClock = Duration.zero;
  var stops = 0;

  setUp(() async {
    stops = 0;
    roundClock = Duration.zero;
    root = await Directory.systemTemp.createTemp('scripture-up-clip');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  ClipSession sessionWith({bool fail = false, Completer<void>? gate}) {
    return ClipSession(
      recorderFactory: () => FakeRoundRecorder(root, fail: fail, gate: gate),
      store: RecordingStore(root),
      clock: () => DateTime(2026, 9, 23, 22, 49, 55, 10),
      elapsed: () => roundClock,
      onStopped: () async => stops += 1,
    );
  }

  RoundMark markAt(int tMs, {String id = 'a'}) {
    return RoundMark(cardId: id, prompt: id, clue: 'clue', correct: true, tMs: tMs);
  }

  test('a camera that never starts leaves the round playable', () async {
    final session = sessionWith(fail: true);
    await session.begin();
    await session.finish();
    expect(session.clip, isA<ClipUnavailable>());
    expect((session.clip as ClipUnavailable).reason, contains('still plays'));
    session.dispose();
  });

  test('save keeps the clip and delete wipes it', () async {
    final session = sessionWith();
    await session.begin();
    await session.finish();
    final pending = session.clip as ClipPending;
    expect(await pending.file.readAsBytes(), [7, 7, 7, 7]);

    await session.save();
    final saved = session.clip as ClipSaved;
    expect(await pending.file.exists(), isFalse);
    expect(await saved.file.readAsBytes(), [7, 7, 7, 7]);
    expect(saved.file.path, contains('recordings/round-20260923-224955-010.mp4'));

    await session.delete();
    expect(session.clip, isA<ClipDeleted>());
    expect(await saved.file.exists(), isFalse);
    session.dispose();
  });

  test('leaving before the camera is ready wipes the clip', () async {
    final gate = Completer<void>();
    final session = sessionWith(gate: gate);
    final starting = session.begin();
    final leaving = session.abandon();
    gate.complete();
    await starting;
    await leaving;
    expect(session.clip, isA<ClipDeleted>());
    final leftovers = root.listSync(recursive: true).whereType<File>();
    expect(leftovers, isEmpty);
    session.dispose();
  });

  test('marks are timed from when the video actually started, not when the countdown did', () async {
    final gate = Completer<void>();
    final session = sessionWith(gate: gate);
    roundClock = const Duration(seconds: 100);
    final starting = session.begin();
    roundClock = const Duration(seconds: 101, milliseconds: 500);
    gate.complete();
    await starting;
    expect(session.live, isTrue);
    expect(session.origin, const Duration(seconds: 101, milliseconds: 500));

    final onClip = session.marksOnClip([markAt(104200), markAt(101000, id: 'early')]);
    expect(onClip.map((mark) => mark.tMs), [2700, 0]);
    expect(onClip.map((mark) => mark.cardId), ['a', 'early']);
    session.dispose();
  });

  test('a camera that never starts leaves marks untouched and no origin', () async {
    final session = sessionWith(fail: true);
    await session.begin();
    expect(session.origin, isNull);
    expect(session.marksOnClip([markAt(5000)]).single.tMs, 5000);
    session.dispose();
  });

  test('save writes the marks on the clip timeline and deleting removes the sidecar too', () async {
    final session = sessionWith();
    roundClock = const Duration(seconds: 10);
    await session.begin();
    await session.finish();
    await session.save(marks: [markAt(12700)]);
    final saved = (session.clip as ClipSaved).file;
    final store = RecordingStore(root);
    expect(store.marksFor(saved).single.tMs, 2700);
    expect(store.folder.listSync().whereType<File>(), hasLength(2));

    await session.delete();
    expect(session.clip, isA<ClipDeleted>());
    expect(store.folder.listSync(), isEmpty);
    session.dispose();
  });

  test('the audio session is restored once a recording has stopped, and only then', () async {
    final session = sessionWith();
    await session.begin();
    expect(stops, 0);
    await session.finish();
    expect(stops, 1);
    session.dispose();

    stops = 0;
    final failing = sessionWith(fail: true);
    await failing.begin();
    await failing.finish();
    expect(stops, 0);
    failing.dispose();
  });
}

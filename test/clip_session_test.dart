import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/recording/clip_session.dart';
import 'package:scripture_up/recording/recording_store.dart';

import 'support/fake_recorder.dart';

void main() {
  late Directory root;

  setUp(() async {
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
    );
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
}

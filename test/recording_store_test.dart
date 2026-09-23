import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/recording/recording_store.dart';

void main() {
  late Directory root;
  late RecordingStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('scripture-up-store');
    store = RecordingStore(root);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('save keeps the bytes and removes the temp file', () async {
    final temp = File('${root.path}/incoming.mp4');
    await temp.writeAsBytes(const [1, 2, 3, 4]);

    final saved = await store.save(
      temp,
      id: clipId(DateTime(2026, 9, 23, 22, 49, 55, 123)),
    );

    expect(await temp.exists(), isFalse);
    expect(await saved.readAsBytes(), [1, 2, 3, 4]);
    expect(saved.path, endsWith('round-20260923-224955-123.mp4'));
    expect((await store.listSaved()).single.path, saved.path);
    expect(clipLabel(saved.uri.pathSegments.last), 'Sep 23, 2026 · 10:49 PM');
  });

  test('discard wipes a temp file and a second discard is a no-op', () async {
    final temp = File('${root.path}/incoming.mp4');
    await temp.writeAsBytes(const [9]);
    await store.discard(temp);
    expect(await temp.exists(), isFalse);
    await store.discard(temp);
    await store.discard(null);
  });

  test('deleteSaved removes a kept clip and ignores a missing file', () async {
    final temp = File('${root.path}/incoming.mp4');
    await temp.writeAsBytes(const [5]);
    final saved = await store.save(temp, id: 'round-20260923-224955-001');
    await store.deleteSaved(saved);
    expect(await saved.exists(), isFalse);
    expect(await store.listSaved(), isEmpty);
    await store.deleteSaved(saved);
  });

  test('saving a missing file throws and leaves the library empty', () async {
    final missing = File('${root.path}/gone.mp4');
    await expectLater(store.save(missing, id: 'round-x'), throwsStateError);
    expect(await store.listSaved(), isEmpty);
  });

  test('newer clip names sort first', () async {
    Future<void> keep(String id) async {
      final temp = File('${root.path}/$id-src.mp4');
      await temp.writeAsBytes(const [1]);
      await store.save(temp, id: id);
    }

    await keep('round-20260923-224955-001');
    await keep('round-20260923-225501-001');
    final saved = await store.listSaved();
    expect(saved.map((file) => file.uri.pathSegments.last).toList(), [
      'round-20260923-225501-001.mp4',
      'round-20260923-224955-001.mp4',
    ]);
  });
}

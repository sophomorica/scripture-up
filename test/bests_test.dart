import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/store/bests.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('scripture-up-bests');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('a corrupt bests file reads as empty and the next score repairs it', () async {
    final file = File('${root.path}/bests.json')..writeAsStringSync('{"bom:60": 7');
    final store = BestStore(file);
    expect(store.read('bom', 60), isNull);

    await store.write('bom', 60, 5);
    expect(store.read('bom', 60), 5);
    expect(BestStore(file).read('bom', 60), 5);
  });

  test('bests that are not a map, or hold non-numbers, keep only the valid scores', () async {
    final file = File('${root.path}/bests.json')..writeAsStringSync('[1, 2]');
    expect(BestStore(file).read('bom', 60), isNull);

    file.writeAsStringSync('{"bom:60": "many", "ot:30": 4}');
    final store = BestStore(file);
    expect(store.read('bom', 60), isNull);
    expect(store.read('ot', 30), 4);
    await store.write('bom', 60, 2);
    expect(BestStore(file).read('ot', 30), 4);
    expect(BestStore(file).read('bom', 60), 2);
  });

  test('a corrupt prefs file launches with the defaults', () async {
    final file = File('${root.path}/prefs.json')..writeAsStringSync('\u0000\u0000garbage');
    final prefs = PlayPrefs(file)..load();
    expect(prefs.respectSilence, isTrue);

    file.writeAsStringSync('{"respectSilence": "yes"}');
    final wrongType = PlayPrefs(file)..load();
    expect(wrongType.respectSilence, isTrue);

    prefs.respectSilence = false;
    await prefs.save();
    final reloaded = PlayPrefs(file)..load();
    expect(reloaded.respectSilence, isFalse);
  });

  test('a write replaces the file whole and leaves no temp file behind', () async {
    final file = File('${root.path}/data/bests.json');
    final store = BestStore(file);
    await store.write('bom', 60, 3);
    await store.write('bom', 60, 9);
    await store.write('nt', 30, 1);

    expect(BestStore(file).read('bom', 60), 9);
    expect(BestStore(file).read('nt', 30), 1);
    final names = file.parent.listSync().map((entry) => entry.uri.pathSegments.last);
    expect(names, ['bests.json']);
  });

  test('a half-written temp file from a crash does not disturb the real file', () async {
    final file = File('${root.path}/bests.json');
    final store = BestStore(file);
    await store.write('bom', 60, 4);
    File('${file.path}.tmp').writeAsStringSync('{"bom:60": 9');

    expect(BestStore(file).read('bom', 60), 4);
    await store.write('bom', 60, 6);
    expect(BestStore(file).read('bom', 60), 6);
  });
}

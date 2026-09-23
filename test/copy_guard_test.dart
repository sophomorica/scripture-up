import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'player-facing copy keeps the product name and drops trademarked labels',
    () {
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final text = sources.map((file) => file.readAsStringSync()).join('\n');
      final lowered = text.toLowerCase();

      expect(text, contains('Scripture Up'));
      expect(lowered, isNot(contains('doctrinal mastery')));
      expect(lowered, isNot(contains('heads up')));
      expect(RegExp(r'\bctr\b', caseSensitive: false).hasMatch(text), isFalse);
    },
  );
}

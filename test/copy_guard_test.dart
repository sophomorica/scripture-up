import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'player-facing copy keeps the product name and drops trademarked labels',
    () {
      final sources = [
        ...Directory('lib').listSync(recursive: true),
        ...Directory('assets/decks').listSync(recursive: true),
      ].whereType<File>().where(
        (file) => file.path.endsWith('.dart') || file.path.endsWith('.json'),
      );
      final text = sources.map((file) => file.readAsStringSync()).join('\n');
      final lowered = text.toLowerCase();

      expect(text, contains('Scripture Up'));
      expect(lowered, isNot(contains('doctrinal mastery')));
      expect(lowered, isNot(contains('heads up')));
      expect(RegExp(r'\bctr\b', caseSensitive: false).hasMatch(text), isFalse);
      final bundledFontsLackArrows = RegExp(r'[\u2190-\u21FF\u25A0-\u25FF]');
      final libText = [
        for (final file in Directory('lib').listSync(recursive: true))
          if (file is File && file.path.endsWith('.dart')) file.readAsStringSync(),
      ].join('\n');
      expect(bundledFontsLackArrows.hasMatch(libText), isFalse);
      for (final retired in [
        'act it out',
        'never say the words',
        'don’t peek',
        'say the reference',
      ]) {
        expect(lowered, isNot(contains(retired)), reason: retired);
      }
    },
  );
}

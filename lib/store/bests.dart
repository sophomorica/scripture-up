import 'dart:convert';
import 'dart:io';

import 'atomic_write.dart';

class BestStore {
  BestStore(this.file);

  final File file;

  int? read(String deckId, int seconds) {
    final map = _load();
    return map['$deckId:$seconds'];
  }

  Future<void> write(String deckId, int seconds, int score) async {
    final map = _load();
    final key = '$deckId:$seconds';
    final previous = map[key];
    if (previous != null && previous >= score) {
      return;
    }
    map[key] = score;
    writeAtomically(file, jsonEncode(map));
  }

  Map<String, int> _load() {
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FileSystemException {
      return {};
    } on FormatException {
      return {};
    }
    if (decoded is! Map) {
      return {};
    }
    return {
      for (final entry in decoded.entries)
        if (entry.value is int) '${entry.key}': entry.value as int,
    };
  }
}

class PlayPrefs {
  PlayPrefs(this.file);

  final File file;

  bool respectSilence = true;

  void load() {
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FileSystemException {
      return;
    } on FormatException {
      return;
    }
    if (decoded is Map && decoded['respectSilence'] is bool) {
      respectSilence = decoded['respectSilence'] as bool;
    }
  }

  Future<void> save() async {
    writeAtomically(file, jsonEncode({'respectSilence': respectSilence}));
  }
}

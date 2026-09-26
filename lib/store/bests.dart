import 'dart:convert';
import 'dart:io';

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
    file.parent.createSync(recursive: true);
    await file.writeAsString(jsonEncode(map));
  }

  Map<String, int> _load() {
    if (!file.existsSync()) {
      return {};
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      return {};
    }
    return decoded.map((key, value) => MapEntry('$key', value as int));
  }
}

class PlayPrefs {
  PlayPrefs(this.file);

  final File file;

  bool respectSilence = true;

  void load() {
    if (!file.existsSync()) {
      return;
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map && decoded['respectSilence'] is bool) {
      respectSilence = decoded['respectSilence'] as bool;
    }
  }

  Future<void> save() async {
    file.parent.createSync(recursive: true);
    await file.writeAsString(jsonEncode({'respectSilence': respectSilence}));
  }
}

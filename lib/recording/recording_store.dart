import 'dart:convert';
import 'dart:io';

import '../store/atomic_write.dart';
import 'moments.dart';

class RecordingStore {
  RecordingStore(this.root);

  final Directory root;

  Directory get folder => Directory('${root.path}/recordings');

  Future<File> save(
    File temp, {
    required String id,
    List<RoundMark> marks = const [],
  }) async {
    if (!temp.existsSync()) {
      throw StateError('Recording file is already gone');
    }
    folder.createSync(recursive: true);
    final saved = File('${folder.path}/$id.mp4');
    saved.writeAsBytesSync(temp.readAsBytesSync(), flush: true);
    writeAtomically(
      _sidecar(saved),
      jsonEncode({'marks': [for (final mark in marks) mark.toJson()]}),
    );
    if (temp.absolute.path != saved.absolute.path && temp.existsSync()) {
      temp.deleteSync();
    }
    return saved;
  }

  List<RoundMark> marksFor(File clip) {
    try {
      final json = jsonDecode(_sidecar(clip).readAsStringSync());
      final marks = (json as Map<String, Object?>)['marks'] as List<Object?>? ?? const [];
      return [
        for (final entry in marks)
          if (entry is Map<String, Object?>) RoundMark.fromJson(entry),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> discard(File? temp) async {
    if (temp == null) {
      return;
    }
    if (temp.existsSync()) {
      temp.deleteSync();
    }
  }

  Future<void> deleteSaved(File saved) async {
    for (final file in [saved, _sidecar(saved)]) {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }

  File _sidecar(File clip) {
    final path = clip.path;
    final stem = path.endsWith('.mp4') ? path.substring(0, path.length - 4) : path;
    return File('$stem.json');
  }

  List<File> savedClips() {
    if (!folder.existsSync()) {
      return const [];
    }
    final files = folder
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.mp4'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<List<File>> listSaved() async => savedClips();
}

String clipId(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  String three(int value) => value.toString().padLeft(3, '0');
  return 'round-${time.year}${two(time.month)}${two(time.day)}-'
      '${two(time.hour)}${two(time.minute)}${two(time.second)}-'
      '${three(time.millisecond)}';
}

String clipLabel(String fileName) {
  final match = RegExp(r'round-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})')
      .firstMatch(fileName);
  if (match == null) {
    return fileName;
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = match.group(5)!;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '${months[month - 1]} $day, $year · $hour12:$minute $suffix';
}

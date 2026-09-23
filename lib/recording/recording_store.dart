import 'dart:io';

class RecordingStore {
  RecordingStore(this.root);

  final Directory root;

  Directory get folder => Directory('${root.path}/recordings');

  Future<File> save(File temp, {required String id}) async {
    if (!temp.existsSync()) {
      throw StateError('Recording file is already gone');
    }
    folder.createSync(recursive: true);
    final saved = File('${folder.path}/$id.mp4');
    saved.writeAsBytesSync(temp.readAsBytesSync(), flush: true);
    if (temp.absolute.path != saved.absolute.path && temp.existsSync()) {
      temp.deleteSync();
    }
    return saved;
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
    if (saved.existsSync()) {
      saved.deleteSync();
    }
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

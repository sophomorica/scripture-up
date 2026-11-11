import 'dart:io';

void writeAtomically(File file, String contents) {
  file.parent.createSync(recursive: true);
  final temp = File('${file.path}.tmp');
  temp.writeAsStringSync(contents, flush: true);
  temp.renameSync(file.path);
}

import 'dart:io';

class RecorderStart {
  const RecorderStart({required this.recording, this.reason});

  final bool recording;
  final String? reason;
}

abstract class RoundRecorder {
  Future<RecorderStart> start();

  Future<File?> stop();
}

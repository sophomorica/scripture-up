import 'dart:async';
import 'dart:io';

import 'package:scripture_up/recording/round_recorder.dart';

class FakeRoundRecorder implements RoundRecorder {
  FakeRoundRecorder(this.directory, {this.fail = false, this.gate});

  final Directory directory;
  final bool fail;
  final Completer<void>? gate;
  var started = false;

  @override
  Future<RecorderStart> start() async {
    final gate = this.gate;
    if (gate != null) {
      await gate.future;
    }
    if (fail) {
      return const RecorderStart(
        recording: false,
        reason: 'Camera could not start. The round still plays.',
      );
    }
    started = true;
    return const RecorderStart(recording: true);
  }

  @override
  Future<File?> stop() async {
    if (!started) {
      return null;
    }
    started = false;
    final file = File(
      '${directory.path}/temp-${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    file.writeAsBytesSync(const [7, 7, 7, 7]);
    return file;
  }
}

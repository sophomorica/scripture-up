import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'recording_store.dart';
import 'round_recorder.dart';

sealed class RoundClip {
  const RoundClip();
}

class ClipOff extends RoundClip {
  const ClipOff();
}

class ClipUnavailable extends RoundClip {
  const ClipUnavailable(this.reason);

  final String reason;
}

class ClipPending extends RoundClip {
  const ClipPending(this.file);

  final File file;
}

class ClipSaved extends RoundClip {
  const ClipSaved(this.file);

  final File file;
}

class ClipDeleted extends RoundClip {
  const ClipDeleted();
}

class ClipSession extends ChangeNotifier {
  ClipSession({
    required this.recorderFactory,
    required this.store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RoundRecorder Function() recorderFactory;
  final RecordingStore store;
  final DateTime Function() _clock;

  RoundClip clip = const ClipOff();
  var live = false;

  RoundRecorder? _recorder;
  Future<RecorderStart>? _startup;
  Future<void>? _sealFuture;
  var _discard = false;
  var _closed = false;

  Future<void> begin() async {
    if (_startup != null) {
      _discard = true;
      await seal();
      await _dropPending();
    }
    _sealFuture = null;
    _discard = false;
    live = false;
    clip = const ClipOff();
    final recorder = recorderFactory();
    _recorder = recorder;
    _startup = _begin(recorder);
    _notify();
    await _startup;
  }

  Future<void> finish() => seal();

  Future<void> abandon() async {
    _discard = true;
    await seal();
    await _dropPending();
  }

  Future<void> dropUnsaved() => _dropPending();

  Future<void> save() async {
    final current = clip;
    if (current is! ClipPending) {
      return;
    }
    final saved = await store.save(current.file, id: clipId(_clock()));
    clip = ClipSaved(saved);
    _notify();
  }

  Future<void> delete() async {
    final current = clip;
    if (current is ClipPending) {
      await store.discard(current.file);
    } else if (current is ClipSaved) {
      await store.deleteSaved(current.file);
    } else {
      return;
    }
    clip = const ClipDeleted();
    _notify();
  }

  @visibleForTesting
  Future<void> seal() {
    return _sealFuture ??= _sealBody();
  }

  Future<RecorderStart> _begin(RoundRecorder recorder) async {
    const fallback = 'Camera could not start. The round still plays.';
    try {
      final result = await recorder.start();
      if (_recorder != recorder) {
        return const RecorderStart(recording: false);
      }
      if (result.recording && !_discard && !_closed) {
        live = true;
        _notify();
      } else if (!result.recording && !_closed && !_discard) {
        clip = ClipUnavailable(result.reason ?? fallback);
        _notify();
      }
      return result;
    } catch (_) {
      if (_recorder == recorder && !_closed && !_discard) {
        clip = const ClipUnavailable(fallback);
        _notify();
      }
      return const RecorderStart(recording: false, reason: fallback);
    }
  }

  Future<void> _sealBody() async {
    final result =
        await (_startup ??
            Future.value(
              const RecorderStart(
                recording: false,
                reason: 'No recording this round.',
              ),
            ));
    live = false;
    if (!result.recording) {
      if (!_closed && !_discard && clip is ClipOff) {
        clip = ClipUnavailable(result.reason ?? 'No recording this round.');
        _notify();
      }
      return;
    }
    final recorder = _recorder;
    File? file;
    if (recorder != null) {
      try {
        file = await recorder.stop();
      } catch (_) {
        file = null;
      }
    }
    if (_closed || _discard) {
      if (file != null) {
        await store.discard(file);
      }
      if (!_closed && clip is! ClipSaved) {
        clip = const ClipDeleted();
        _notify();
      }
      return;
    }
    if (file == null) {
      clip = const ClipUnavailable('Recording did not finish.');
    } else {
      clip = ClipPending(file);
    }
    _notify();
  }

  Future<void> _dropPending() async {
    final current = clip;
    if (current is ClipPending) {
      await store.discard(current.file);
      clip = const ClipDeleted();
      _notify();
    }
  }

  void _notify() {
    if (!_closed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    _discard = true;
    unawaited(seal());
    super.dispose();
  }
}

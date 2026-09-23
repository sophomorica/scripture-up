import 'dart:io';

import 'package:camera/camera.dart';

import 'round_recorder.dart';

class CameraRoundRecorder implements RoundRecorder {
  CameraController? _controller;
  var _capturing = false;

  @override
  Future<RecorderStart> start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        return const RecorderStart(
          recording: false,
          reason: 'No camera on this phone. The round still plays.',
        );
      }
      final front = cameras.cast<CameraDescription?>().firstWhere(
        (camera) => camera!.lensDirection == CameraLensDirection.front,
        orElse: () => null,
      );
      final camera = front ?? cameras.first;
      final opened = await _open(camera);
      if (!opened) {
        return const RecorderStart(
          recording: false,
          reason: 'Camera could not start. The round still plays.',
        );
      }
      await _controller!.startVideoRecording();
      _capturing = true;
      return const RecorderStart(recording: true);
    } on CameraException catch (error) {
      await _tearDown();
      return RecorderStart(recording: false, reason: _reason(error));
    } catch (_) {
      await _tearDown();
      return const RecorderStart(
        recording: false,
        reason: 'Camera could not start. The round still plays.',
      );
    }
  }

  Future<bool> _open(CameraDescription camera) async {
    try {
      await _attach(camera, fps: 24, videoBitrate: 800000);
      return true;
    } catch (_) {
      await _dropController();
      try {
        await _attach(camera);
        return true;
      } catch (_) {
        await _tearDown();
        return false;
      }
    }
  }

  Future<void> _attach(
    CameraDescription camera, {
    int? fps,
    int? videoBitrate,
  }) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: true,
      fps: fps,
      videoBitrate: videoBitrate,
      audioBitrate: 64000,
    );
    _controller = controller;
    await controller.initialize();
  }

  @override
  Future<File?> stop() async {
    final controller = _controller;
    if (controller == null) {
      return null;
    }
    try {
      if (!_capturing) {
        return null;
      }
      final shot = await controller.stopVideoRecording();
      _capturing = false;
      return File(shot.path);
    } catch (_) {
      return null;
    } finally {
      await _tearDown();
    }
  }

  Future<void> _dropController() async {
    final controller = _controller;
    _controller = null;
    _capturing = false;
    if (controller != null) {
      await controller.dispose();
    }
  }

  Future<void> _tearDown() => _dropController();

  String _reason(CameraException error) {
    if (error.code == 'CameraAccessDenied' ||
        error.code == 'AudioAccessDenied' ||
        error.code == 'CameraAccessDeniedWithoutPrompt') {
      return 'Camera permission is off. The round still plays.';
    }
    return 'Camera could not start. The round still plays.';
  }
}

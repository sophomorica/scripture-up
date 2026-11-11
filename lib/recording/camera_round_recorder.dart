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
      await _open(camera);
      await _controller!.startVideoRecording();
      _capturing = true;
      return const RecorderStart(recording: true);
    } on CameraException catch (error) {
      await _tearDown();
      return RecorderStart(recording: false, reason: cameraFailureReason(error));
    } catch (_) {
      await _tearDown();
      return const RecorderStart(
        recording: false,
        reason: 'Camera could not start. The round still plays.',
      );
    }
  }

  Future<void> _open(CameraDescription camera) async {
    try {
      await _attachTuned(camera, audio: true);
    } on CameraException catch (error) {
      if (!_audioPermission.contains(error.code)) {
        rethrow;
      }
      await _dropController();
      await _attachTuned(camera, audio: false);
    }
  }

  Future<void> _attachTuned(CameraDescription camera, {required bool audio}) async {
    try {
      await _attach(camera, audio: audio, fps: 24, videoBitrate: 800000);
    } catch (error) {
      if (error is CameraException && _isPermission(error.code)) {
        rethrow;
      }
      await _dropController();
      await _attach(camera, audio: audio);
    }
  }

  Future<void> _attach(
    CameraDescription camera, {
    required bool audio,
    int? fps,
    int? videoBitrate,
  }) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: audio,
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

  bool _isPermission(String code) =>
      _audioPermission.contains(code) || _cameraPermission.contains(code);
}

const _cameraPermission = {
  'CameraAccessDenied',
  'CameraAccessDeniedWithoutPrompt',
  'CameraAccessRestricted',
};

const _audioPermission = {
  'AudioAccessDenied',
  'AudioAccessDeniedWithoutPrompt',
  'AudioAccessRestricted',
};

String cameraFailureReason(CameraException error) {
  return switch (error.code) {
    'CameraAccessDenied' ||
    'CameraAccessDeniedWithoutPrompt' =>
      'Camera permission is off. The round still plays.',
    'CameraAccessRestricted' =>
      'Camera access is restricted on this phone. The round still plays.',
    'AudioAccessDenied' ||
    'AudioAccessDeniedWithoutPrompt' =>
      'Microphone permission is off. The round still plays.',
    'AudioAccessRestricted' =>
      'Microphone access is restricted on this phone. The round still plays.',
    _ => 'Camera could not start. The round still plays.',
  };
}

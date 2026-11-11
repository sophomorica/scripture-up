import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/recording/camera_round_recorder.dart';
import 'package:scripture_up/recording/round_recorder.dart';

class FakeCameraPlatform extends CameraPlatform {
  FakeCameraPlatform({this.refuse});

  final CameraException? Function(MediaSettings settings)? refuse;
  final attempts = <MediaSettings>[];
  final _quiet = StreamController<CameraErrorEvent>.broadcast();
  var disposed = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 0,
    ),
  ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    attempts.add(mediaSettings);
    final error = refuse?.call(mediaSettings);
    if (error != null) {
      throw error;
    }
    return attempts.length;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          320,
          240,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      );

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _quiet.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}

  @override
  Future<void> startVideoCapturing(VideoCaptureOptions options) async {}

  @override
  Future<XFile> stopVideoRecording(int cameraId) async => XFile('/tmp/clip.mp4');

  @override
  Future<void> dispose(int cameraId) async => disposed += 1;
}

CameraException denied(String code) => CameraException(code, 'denied');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CameraPlatform original;

  setUp(() {
    original = CameraPlatform.instance;
  });

  tearDown(() {
    CameraPlatform.instance = original;
  });

  Future<RecorderResult> run(FakeCameraPlatform platform) async {
    CameraPlatform.instance = platform;
    final recorder = CameraRoundRecorder();
    final start = await recorder.start();
    return RecorderResult(recorder, start);
  }

  test('with every permission granted it records video and audio at the tuned settings', () async {
    final platform = FakeCameraPlatform();
    final result = await run(platform);
    expect(result.start.recording, isTrue);
    expect(platform.attempts, hasLength(1));
    expect(platform.attempts.single.enableAudio, isTrue);
    expect(platform.attempts.single.fps, 24);
    expect(platform.attempts.single.videoBitrate, 800000);
    expect(await result.recorder.stop(), isNotNull);
  });

  for (final code in [
    'AudioAccessDenied',
    'AudioAccessDeniedWithoutPrompt',
    'AudioAccessRestricted',
  ]) {
    test('$code still records, once, video only', () async {
      final platform = FakeCameraPlatform(
        refuse: (settings) => settings.enableAudio ? denied(code) : null,
      );
      final result = await run(platform);
      expect(result.start.recording, isTrue);
      expect(platform.attempts.map((attempt) => attempt.enableAudio), [true, false]);
      expect(platform.attempts.last.fps, 24);
      expect(platform.disposed, 1, reason: 'the refused controller is released');
    });
  }

  test('a refused camera says why and is not retried', () async {
    final denial = FakeCameraPlatform(refuse: (_) => denied('CameraAccessDenied'));
    final first = await run(denial);
    expect(first.start.recording, isFalse);
    expect(first.start.reason, contains('Camera permission is off'));
    expect(denial.attempts, hasLength(1));

    final noPrompt = await run(
      FakeCameraPlatform(refuse: (_) => denied('CameraAccessDeniedWithoutPrompt')),
    );
    expect(noPrompt.start.reason, contains('Camera permission is off'));

    final restricted = await run(
      FakeCameraPlatform(refuse: (_) => denied('CameraAccessRestricted')),
    );
    expect(restricted.start.reason, contains('restricted'));
  });

  test('a settings failure falls back to the platform defaults and keeps the audio', () async {
    final platform = FakeCameraPlatform(
      refuse: (settings) =>
          settings.fps != null ? CameraException('InvalidFps', 'no') : null,
    );
    final result = await run(platform);
    expect(result.start.recording, isTrue);
    expect(platform.attempts, hasLength(2));
    expect(platform.attempts.last.fps, isNull);
    expect(platform.attempts.last.enableAudio, isTrue);
  });

  test('every permission code maps to its own reason', () {
    String reason(String code) => cameraFailureReason(CameraException(code, null));
    expect(reason('CameraAccessDenied'), contains('Camera permission'));
    expect(reason('CameraAccessDeniedWithoutPrompt'), contains('Camera permission'));
    expect(reason('CameraAccessRestricted'), contains('Camera access is restricted'));
    expect(reason('AudioAccessDenied'), contains('Microphone permission'));
    expect(reason('AudioAccessDeniedWithoutPrompt'), contains('Microphone permission'));
    expect(reason('AudioAccessRestricted'), contains('Microphone access is restricted'));
    expect(reason('SomethingElse'), contains('Camera could not start'));
  });
}

class RecorderResult {
  RecorderResult(this.recorder, this.start);

  final CameraRoundRecorder recorder;
  final RecorderStart start;
}

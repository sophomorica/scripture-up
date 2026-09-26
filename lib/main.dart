import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'feedback/device_audio.dart';
import 'feedback/game_haptics.dart';
import 'game/tilt_sensor.dart';
import 'recording/camera_round_recorder.dart';
import 'store/bests.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final documents = await getApplicationDocumentsDirectory();
  final prefs = PlayPrefs(File('${documents.path}/prefs.json'))..load();
  runApp(
    ScriptureUpApp(
      documentsDirectory: documents,
      sensor: DeviceTiltSensor(),
      audio: DeviceGameAudio(respectSilence: prefs.respectSilence),
      haptics: DeviceHaptics(),
      recorderFactory: CameraRoundRecorder.new,
      prefs: prefs,
    ),
  );
}

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'game/decks.dart';
import 'game/device_tilt.dart';
import 'game/scripture_card.dart';
import 'game/tilt.dart';
import 'recording/camera_round_recorder.dart';
import 'recording/recording_store.dart';
import 'recording/round_recorder.dart';
import 'ui/home_screen.dart';
import 'ui/library_screen.dart';
import 'ui/round_screen.dart';
import 'ui/theme.dart';

const defaultRoundLengths = <Duration>[
  Duration(seconds: 30),
  Duration(seconds: 60),
  Duration(seconds: 90),
];

class ScriptureUpApp extends StatefulWidget {
  const ScriptureUpApp({
    super.key,
    required this.documentsDirectory,
    this.recorderFactory,
    this.tiltReadings,
    this.decks = scriptureDecks,
    this.lengths = defaultRoundLengths,
    this.countdown = const Duration(seconds: 3),
    this.random,
    this.clock,
  });

  final Directory documentsDirectory;
  final RoundRecorder Function()? recorderFactory;
  final Stream<TiltReading>? tiltReadings;
  final List<Deck> decks;
  final List<Duration> lengths;
  final Duration countdown;
  final Random Function()? random;
  final DateTime Function()? clock;

  @override
  State<ScriptureUpApp> createState() => _ScriptureUpAppState();
}

class _ScriptureUpAppState extends State<ScriptureUpApp> {
  late final RecordingStore _store = RecordingStore(widget.documentsDirectory);

  RoundRecorder _recorder() {
    final factory = widget.recorderFactory;
    if (factory != null) {
      return factory();
    }
    return CameraRoundRecorder();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scripture Up',
      theme: scriptureTheme(),
      home: _HomeShell(
        decks: widget.decks,
        lengths: widget.lengths,
        store: _store,
        recorderFactory: _recorder,
        tilt: widget.tiltReadings,
        countdown: widget.countdown,
        random: widget.random,
        clock: widget.clock,
      ),
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({
    required this.decks,
    required this.lengths,
    required this.store,
    required this.recorderFactory,
    required this.tilt,
    required this.countdown,
    required this.random,
    required this.clock,
  });

  final List<Deck> decks;
  final List<Duration> lengths;
  final RecordingStore store;
  final RoundRecorder Function() recorderFactory;
  final Stream<TiltReading>? tilt;
  final Duration countdown;
  final Random Function()? random;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      decks: decks,
      lengths: lengths,
      onPlay: (deck, length) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RoundScreen(
              deck: deck,
              length: length,
              store: store,
              recorderFactory: recorderFactory,
              tilt: tilt ?? deviceTilt(),
              countdown: countdown,
              random: random?.call(),
              clock: clock,
            ),
          ),
        );
      },
      onOpenLibrary: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => LibraryScreen(store: store)),
        );
      },
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feedback/game_audio.dart';
import 'feedback/game_haptics.dart';
import 'game/deck.dart';
import 'game/tilt_detector.dart';
import 'game/tilt_sensor.dart';
import 'recording/recording_store.dart';
import 'recording/round_recorder.dart';
import 'store/bests.dart';
import 'ui/library_screen.dart';
import 'ui/lobby_screen.dart';
import 'ui/round_screen.dart';
import 'ui/sheets.dart';
import 'ui/style.dart';

class ScriptureUpApp extends StatefulWidget {
  const ScriptureUpApp({
    super.key,
    required this.documentsDirectory,
    this.decks,
    this.sensor,
    this.audio,
    this.haptics,
    this.recorderFactory,
    this.clock,
    this.elapsed,
    this.random,
    this.prefs,
  });

  final Directory documentsDirectory;
  final List<Deck>? decks;
  final TiltSensor? sensor;
  final GameAudio? audio;
  final GameHaptics? haptics;
  final RoundRecorder Function()? recorderFactory;
  final DateTime Function()? clock;
  final Duration Function()? elapsed;
  final Random Function()? random;
  final PlayPrefs? prefs;

  @override
  State<ScriptureUpApp> createState() => _ScriptureUpAppState();
}

class _ScriptureUpAppState extends State<ScriptureUpApp> {
  List<Deck>? _decks;

  @override
  void initState() {
    super.initState();
    final given = widget.decks;
    if (given != null) {
      _decks = given;
    } else {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final decks = <Deck>[];
    for (final path in deckAssetPaths) {
      decks.add(parseDeck(await rootBundle.loadString(path)));
    }
    if (mounted) {
      setState(() => _decks = decks);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decks = _decks;
    return MaterialApp(
      title: 'Scripture Up',
      theme: scriptureTheme(),
      home: decks == null
          ? const Scaffold(
              backgroundColor: ink,
              body: Center(child: CircularProgressIndicator(color: goldLeaf)),
            )
          : _Table(
              decks: decks,
              documents: widget.documentsDirectory,
              sensor: widget.sensor ?? ScriptedTiltSensor(const Stream.empty()),
              audio: widget.audio ?? SilentAudio(),
              haptics: widget.haptics ?? SilentHaptics(),
              recorderFactory: widget.recorderFactory,
              clock: widget.clock,
              elapsed: widget.elapsed,
              random: widget.random,
              prefs: widget.prefs,
            ),
    );
  }
}

class _Table extends StatefulWidget {
  const _Table({
    required this.decks,
    required this.documents,
    required this.sensor,
    required this.audio,
    required this.haptics,
    required this.recorderFactory,
    required this.clock,
    required this.elapsed,
    required this.random,
    required this.prefs,
  });

  final List<Deck> decks;
  final Directory documents;
  final TiltSensor sensor;
  final GameAudio audio;
  final GameHaptics haptics;
  final RoundRecorder Function()? recorderFactory;
  final DateTime Function()? clock;
  final Duration Function()? elapsed;
  final Random Function()? random;
  final PlayPrefs? prefs;

  @override
  State<_Table> createState() => _TableState();
}

class _TableState extends State<_Table> {
  late final RecordingStore _store = RecordingStore(widget.documents);
  late final BestStore _bests = BestStore(
    File('${widget.documents.path}/bests.json'),
  );
  late final PlayPrefs _prefs =
      widget.prefs ?? PlayPrefs(File('${widget.documents.path}/prefs.json'));
  late final Stopwatch _watch = Stopwatch()..start();
  final TiltDetector _debugDetector = TiltDetector();

  var _length = const Duration(seconds: 60);
  var _record = false;
  var _tap = false;
  var _about = false;
  var _debug = false;
  double _theta = 0;
  String _phaseName = 'neutral';
  StreamSubscription<AccelSample>? _samples;

  @override
  void initState() {
    super.initState();
    if (widget.prefs == null) {
      _prefs.load();
    }
    unawaited(widget.audio.setRespectSilence(_prefs.respectSilence));
    _samples = widget.sensor.samples.listen((sample) {
      final tick = _debugDetector.ingest(sample, detect: false);
      _theta = tick.theta;
      _phaseName = tick.phase.name;
      if (_debug && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    unawaited(_samples?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  Duration _now() => widget.elapsed?.call() ?? _watch.elapsed;

  RoundRecorder _recorder() {
    final factory = widget.recorderFactory;
    if (factory != null) {
      return factory();
    }
    return _MissingRecorder();
  }

  Future<void> _openSheet(Deck deck) {
    return showDeckSheet(
      context: context,
      deck: deck,
      length: _length,
      record: _record,
      tapMode: _tap,
      onLength: (length) => setState(() => _length = length),
      onRecord: (record) => setState(() => _record = record),
      onTapMode: (tap) => setState(() => _tap = tap),
      onPlay: () => _start(deck),
    );
  }

  void _start(Deck deck) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoundScreen(
          deck: deck,
          length: _length,
          roundNumber: 1,
          tapMode: _tap,
          record: _record,
          store: _store,
          bests: _bests,
          recorderFactory: _recorder,
          sensor: widget.sensor,
          audio: widget.audio,
          haptics: widget.haptics,
          now: _now,
          random: widget.random,
          clock: widget.clock,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LobbyScreen(
          decks: widget.decks,
          length: _length,
          onLength: (length) => setState(() => _length = length),
          onPlay: _openSheet,
          onOpen: _openSheet,
          onVideos: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LibraryScreen(store: _store),
              ),
            );
          },
          onAbout: () => setState(() => _about = true),
        ),
        if (_about)
          Positioned.fill(
            child: AboutSheet(
              respectSilence: _prefs.respectSilence,
              onRespectSilence: (value) {
                setState(() => _prefs.respectSilence = value);
                unawaited(_prefs.save());
                unawaited(widget.audio.setRespectSilence(value));
              },
              onDebug: () => setState(() => _debug = true),
              onClose: () => setState(() => _about = false),
              theta: _debug ? _theta : null,
              phase: _debug ? _phaseName : null,
            ),
          ),
      ],
    );
  }
}

class _MissingRecorder implements RoundRecorder {
  @override
  Future<RecorderStart> start() async {
    return const RecorderStart(
      recording: false,
      reason: 'Camera could not start. The round still plays.',
    );
  }

  @override
  Future<File?> stop() async => null;
}

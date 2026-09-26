import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../feedback/game_audio.dart';
import '../feedback/game_haptics.dart';
import '../game/deck.dart';
import '../game/round_controller.dart';
import '../game/tilt_sensor.dart';
import '../recording/clip_session.dart';
import '../recording/moments.dart';
import '../recording/recording_store.dart';
import '../recording/round_recorder.dart';
import '../store/bests.dart';
import 'results_view.dart';
import 'review_screen.dart';
import 'round_views.dart';

class RoundScreen extends StatefulWidget {
  const RoundScreen({
    super.key,
    required this.deck,
    required this.length,
    required this.store,
    required this.bests,
    required this.recorderFactory,
    required this.sensor,
    required this.audio,
    required this.haptics,
    required this.now,
    this.roundNumber = 1,
    this.tapMode = false,
    this.record = false,
    this.random,
    this.clock,
  });

  final Deck deck;
  final Duration length;
  final RecordingStore store;
  final BestStore bests;
  final RoundRecorder Function() recorderFactory;
  final TiltSensor sensor;
  final GameAudio audio;
  final GameHaptics haptics;
  final Duration Function() now;
  final int roundNumber;
  final bool tapMode;
  final bool record;
  final Random Function()? random;
  final DateTime Function()? clock;

  @override
  State<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends State<RoundScreen>
    with SingleTickerProviderStateMixin {
  late RoundController _round;
  late ClipSession _clips;
  late final Ticker _ticker;
  StreamSubscription<AccelSample>? _samples;
  var _roundNumber = 1;
  var _recordingStarted = false;
  var _recordingFinished = false;
  var _bestWritten = false;
  var _leaving = false;
  int? _expanded;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _roundNumber = widget.roundNumber;
    _clips = _openClips();
    _boot(const {});
    _ticker = createTicker((_) => _round.elapseTo(widget.now()))..start();
    _samples = widget.sensor.samples.listen((sample) {
      _round.sample(AccelSample(sample.x, sample.y, sample.z, widget.now()));
    });
  }

  ClipSession _openClips() {
    final session = ClipSession(
      recorderFactory: widget.recorderFactory,
      store: widget.store,
      clock: widget.clock,
    );
    session.addListener(_onClip);
    return session;
  }

  void _boot(Set<String> unseen) {
    _round = RoundController(
      deck: widget.deck,
      length: widget.length,
      roundNumber: _roundNumber,
      tapMode: widget.tapMode,
      priorBest: widget.bests.read(widget.deck.id, widget.length.inSeconds),
      unseenFirst: unseen,
      random: widget.random?.call(),
    );
    _round.addListener(_onRound);
    _expanded = null;
    _recordingStarted = false;
    _recordingFinished = false;
    _bestWritten = false;
  }

  void _onRound() {
    _playCues();
    _syncRecording();
    _writeBest();
    if (mounted) {
      setState(() {});
    }
  }

  void _onClip() {
    if (mounted) {
      setState(() {});
    }
  }

  void _playCues() {
    for (final cue in _round.drainCues()) {
      final sound = cue.sound;
      if (sound != null) {
        unawaited(widget.audio.play(sound));
      }
      final haptic = cue.haptic;
      if (haptic != null) {
        widget.haptics.play(haptic);
      }
    }
  }

  void _syncRecording() {
    if (!widget.record) {
      return;
    }
    if (!_recordingStarted && _round.phase == RoundPhase.countdown) {
      _recordingStarted = true;
      unawaited(_clips.begin());
    }
    final stop =
        _recordingStarted &&
        !_recordingFinished &&
        (_round.phase == RoundPhase.results ||
            (_round.phase == RoundPhase.timeUp &&
                _round.timeUpElapsed >= const Duration(milliseconds: 1500)));
    if (stop) {
      _recordingFinished = true;
      unawaited(_clips.finish());
    }
  }

  void _writeBest() {
    if (_bestWritten || _round.phase != RoundPhase.results) {
      return;
    }
    _bestWritten = true;
    unawaited(
      widget.bests.write(
        widget.deck.id,
        widget.length.inSeconds,
        _round.got,
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_samples?.cancel() ?? Future<void>.value());
    _round.removeListener(_onRound);
    _round.dispose();
    _clips.removeListener(_onClip);
    if (!_leaving) {
      unawaited(_clips.abandon());
    }
    _clips.dispose();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  bool get _hasFile =>
      _clips.clip is ClipPending || _clips.clip is ClipSaved;

  File? get _clipFile {
    final clip = _clips.clip;
    return switch (clip) {
      ClipPending(:final file) => file,
      ClipSaved(:final file) => file,
      _ => null,
    };
  }

  Future<void> _playAgain() async {
    final unseen = _round.unseenIds;
    await _clips.abandon();
    _round.removeListener(_onRound);
    _round.dispose();
    _clips.removeListener(_onClip);
    _clips.dispose();
    _clips = _openClips();
    setState(() {
      _roundNumber += 1;
      _boot(unseen);
    });
  }

  Future<void> _leave({required bool home}) async {
    if (_leaving) {
      return;
    }
    if (_round.phase == RoundPhase.results && _clips.clip is ClipPending) {
      final keep = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Keep this video?'),
            content: const Text('Save it on this phone, or delete it.'),
            actions: [
              TextButton(
                key: const Key('confirm-delete'),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Delete'),
              ),
              TextButton(
                key: const Key('confirm-save'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      if (keep == null || !mounted) {
        return;
      }
      if (keep) {
        await _save();
      } else {
        await _clips.delete();
      }
    }
    _leaving = true;
    if (mounted) {
      Navigator.of(context).pop(home);
    }
  }

  Future<void> _save() async {
    await _clips.save();
    final file = _clipFile;
    if (file == null) {
      return;
    }
    final sidecar = File(file.path.replaceAll('.mp4', '.json'));
    sidecar.writeAsStringSync(
      jsonEncode({
        'marks': [for (final mark in _round.marks) mark.toJson()],
      }),
    );
  }

  Future<void> _deleteClip() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this recording?'),
          content: const Text('The clip is removed from this phone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            TextButton(
              key: const Key('confirm-delete'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (discard == true) {
      await _clips.delete();
    }
  }

  Future<void> _watch(Duration seek) async {
    final file = _clipFile;
    if (file == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewScreen(
          file: file,
          marks: _round.marks,
          initialSeek: seek,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_leave(home: true));
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(child: _body(reduce)),
      ),
    );
  }

  Widget _body(bool reduce) {
    final phase = _round.phase;
    final card = _round.current;
    return switch (phase) {
      RoundPhase.idle => ForeheadView(
        roundNumber: _roundNumber,
        armProgress: _round.armProgress,
        tapMode: widget.tapMode,
        recording: _clips.live,
        onStart: _round.tapStart,
      ),
      RoundPhase.countdown => CountdownView(
        roundNumber: _roundNumber,
        numeral: _round.numeral,
        progress: _round.beatProgress,
        recording: _clips.live,
      ),
      RoundPhase.card || RoundPhase.paused => Stack(
        fit: StackFit.expand,
        children: [
          CardPlayView(
            color: widget.deck.hero,
            prompt: card?.prompt ?? '',
            clue: card?.clue ?? '',
            got: _round.got,
            timeLeft: _round.timeLeft,
            deckName: widget.deck.name,
            recording: _clips.live,
            tapMode: widget.tapMode,
            urgent: _round.urgent,
            urgentFast: _round.urgentFast,
            pauseProgress: _round.pauseProgress,
            reduceMotion: reduce,
            onCorrect: _round.tapCorrect,
            onPass: _round.tapPass,
            onPauseDown: _round.beginPauseHold,
            onPauseUp: _round.cancelPauseHold,
          ),
          if (phase == RoundPhase.paused)
            PauseScrim(onResume: _round.resume, onEnd: _round.endEarly),
        ],
      ),
      RoundPhase.correct => CorrectFlashView(
        prompt: card?.prompt ?? '',
        timeLeft: _round.timeLeft,
        reduceMotion: reduce,
      ),
      RoundPhase.pass => PassFlashView(
        prompt: card?.prompt ?? '',
        timeLeft: _round.timeLeft,
      ),
      RoundPhase.timeUp => TimeUpView(
        headline: _round.headline,
        score: _round.got,
      ),
      RoundPhase.results => ResultsView(
        headline: _round.headline,
        score: _round.got,
        deckName: widget.deck.name,
        seconds: widget.length.inSeconds,
        passed: _round.passed,
        bestLabel: _round.bestLabel,
        newBest: _round.newBest,
        marks: _round.marks,
        expanded: _expanded,
        hasRecording: _hasFile,
        reduceMotion: reduce,
        onToggle: (index) {
          setState(() => _expanded = _expanded == index ? null : index);
        },
        onJump: (mark) => _watch(jumpTarget(mark.tMs)),
        onPlayAgain: () => unawaited(_playAgain()),
        onNewDeck: () => unawaited(_leave(home: false)),
        onHome: () => unawaited(_leave(home: true)),
        recording: _strip(),
      ),
    };
  }

  Widget _strip() {
    if (!widget.record && _clips.clip is ClipOff) {
      return const SizedBox.shrink();
    }
    final clip = _clips.clip;
    return switch (clip) {
      ClipOff() => RecordingStrip(
        label: 'Starting the camera…',
        onWatch: null,
        onSave: null,
        onDelete: null,
      ),
      ClipUnavailable(:final reason) => RecordingStrip(
        label: reason,
        onWatch: null,
        onSave: null,
        onDelete: null,
      ),
      ClipPending() => RecordingStrip(
        label: 'Round video · stays on this phone',
        canSave: true,
        canDelete: true,
        onWatch: () => unawaited(_watch(Duration.zero)),
        onSave: () => unawaited(_save()),
        onDelete: () => unawaited(_deleteClip()),
      ),
      ClipSaved() => RecordingStrip(
        label: 'Saved on this phone',
        canDelete: true,
        onWatch: () => unawaited(_watch(Duration.zero)),
        onSave: null,
        onDelete: () => unawaited(_deleteClip()),
      ),
      ClipDeleted() => RecordingStrip(
        label: 'Recording deleted',
        onWatch: null,
        onSave: null,
        onDelete: null,
      ),
    };
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_session.dart';
import '../game/round_engine.dart';
import '../game/scripture_card.dart';
import '../game/tilt.dart';
import '../recording/recording_store.dart';
import '../recording/round_recorder.dart';
import 'theme.dart';

class RoundScreen extends StatefulWidget {
  const RoundScreen({
    super.key,
    required this.deck,
    required this.length,
    required this.store,
    required this.recorderFactory,
    required this.tilt,
    this.countdown = const Duration(seconds: 3),
    this.random,
    this.clock,
  });

  final Deck deck;
  final Duration length;
  final RecordingStore store;
  final RoundRecorder Function() recorderFactory;
  final Stream<TiltReading>? tilt;
  final Duration countdown;
  final Random? random;
  final DateTime Function()? clock;

  @override
  State<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends State<RoundScreen> {
  late final GameSession _session;
  var _leaving = false;

  @override
  void initState() {
    super.initState();
    _session = GameSession(
      cards: widget.deck.cards,
      length: widget.length,
      recorderFactory: widget.recorderFactory,
      store: widget.store,
      tilt: widget.tilt,
      random: widget.random,
      clock: widget.clock,
      countdown: widget.countdown,
    );
    _session.addListener(_onSession);
    unawaited(_session.start());
  }

  void _onSession() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    unawaited(_session.leaveRound());
    _session.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving) {
      return;
    }
    setState(() => _leaving = true);
    await _session.leaveRound();
    if (mounted) {
      Navigator.of(context).pop();
    }
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
      await _session.deleteRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = _session.phase;
    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_leave());
        }
      },
      child: switch (phase) {
        null => const Scaffold(backgroundColor: night, body: SizedBox.expand()),
        RoundFinished() => _ResultsBody(
          session: _session,
          onAgain: () => unawaited(_session.playAgain()),
          onDeck: _leave,
          onDelete: _deleteClip,
        ),
        _ => _ForeheadBody(session: _session, onEnd: () => unawaited(_leave())),
      },
    );
  }
}

class _ForeheadBody extends StatelessWidget {
  const _ForeheadBody({required this.session, required this.onEnd});

  final GameSession session;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final phase = session.phase;
    final playing = phase is RoundPlaying ? phase : null;
    final countdown = phase is RoundCountdown ? phase : null;
    return Scaffold(
      backgroundColor: night,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    playing == null ? '' : formatClock(playing.timeLeft),
                    key: const Key('round-clock'),
                    style: const TextStyle(
                      color: amber,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  if (playing != null)
                    Text(
                      '${playing.correct.length} got',
                      style: const TextStyle(
                        color: sand,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  TextButton(
                    key: const Key('end-round'),
                    onPressed: onEnd,
                    child: const Text(
                      'End',
                      style: TextStyle(
                        color: sand,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (session.clip is ClipUnavailable)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Not recording',
                    style: TextStyle(color: sand, fontSize: 14),
                  ),
                ),
              Expanded(
                child: countdown != null
                    ? Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${countdownNumber(countdown.left)}',
                            key: const Key('countdown'),
                            style: const TextStyle(
                              color: ivory,
                              fontSize: 160,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      )
                    : _CardFace(card: playing!.current, banner: session.banner),
              ),
              Row(
                children: [
                  Expanded(
                    child: _RoundButton(
                      key: const Key('pass'),
                      label: 'Pass',
                      color: clay,
                      onPressed: session.markPass,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RoundButton(
                      key: const Key('got-it'),
                      label: 'Got it',
                      color: moss,
                      onPressed: session.markCorrect,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, required this.banner});

  final ScriptureCard card;
  final String? banner;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (banner != null) ...[
          Text(
            banner!,
            key: const Key('round-banner'),
            style: const TextStyle(
              color: amber,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
        ],
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            card.reference,
            key: const Key('card-reference'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ivory,
              fontSize: 56,
              fontWeight: FontWeight.w800,
              height: 1.05,
              letterSpacing: -0.8,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'CLUE',
          style: TextStyle(
            color: sand.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          card.clue,
          key: const Key('card-clue'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: sand,
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: ivory,
        minimumSize: const Size.fromHeight(64),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.session,
    required this.onAgain,
    required this.onDeck,
    required this.onDelete,
  });

  final GameSession session;
  final VoidCallback onAgain;
  final VoidCallback onDeck;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final phase = session.phase! as RoundFinished;
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Text(
              '${phase.correct.length}',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w800,
                color: pine,
                height: 0.95,
              ),
            ),
            const Text(
              'correct',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: moss,
              ),
            ),
            if (phase.deckCleared) ...[
              const SizedBox(height: 8),
              const Text('You cleared the deck.'),
            ],
            const SizedBox(height: 20),
            _OutcomeList(
              title: 'Got it',
              listKey: const Key('got-list'),
              cards: phase.correct,
              empty: 'No correct guesses',
            ),
            const SizedBox(height: 16),
            _OutcomeList(
              title: 'Passed',
              listKey: const Key('passed-list'),
              cards: phase.passed,
              empty: 'No passes',
            ),
            const SizedBox(height: 20),
            _ClipPanel(session: session, onDelete: onDelete),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('play-again'),
              onPressed: onAgain,
              style: FilledButton.styleFrom(
                backgroundColor: pine,
                foregroundColor: ivory,
                minimumSize: const Size.fromHeight(56),
              ),
              child: const Text('Play again'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('change-deck'),
              onPressed: onDeck,
              child: const Text('Change deck'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutcomeList extends StatelessWidget {
  const _OutcomeList({
    required this.title,
    required this.listKey,
    required this.cards,
    required this.empty,
  });

  final String title;
  final Key listKey;
  final List<ScriptureCard> cards;
  final String empty;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: listKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (cards.isEmpty)
            Text(empty, style: TextStyle(color: ink.withValues(alpha: 0.6)))
          else
            for (final card in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  card.reference,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ClipPanel extends StatelessWidget {
  const _ClipPanel({required this.session, required this.onDelete});

  final GameSession session;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final clip = session.clip;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: foam,
        borderRadius: BorderRadius.circular(16),
      ),
      child: switch (clip) {
        ClipOff() => const Text('Finishing the recording…'),
        ClipUnavailable(:final reason) => Text(reason),
        ClipPending() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Keep this round on the phone, or wipe it.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('save-recording'),
              onPressed: () => unawaited(session.saveRecording()),
              style: FilledButton.styleFrom(
                backgroundColor: moss,
                foregroundColor: ivory,
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Save recording'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('delete-recording'),
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: clay,
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: clay),
              ),
              child: const Text('Delete recording'),
            ),
          ],
        ),
        ClipSaved() => const Text(
          'Saved on this phone',
          key: Key('clip-saved'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: pine,
          ),
        ),
        ClipDeleted() => const Text(
          'Recording deleted',
          key: Key('clip-deleted'),
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      },
    );
  }
}

const amber = Color(0xFFE6A15C);

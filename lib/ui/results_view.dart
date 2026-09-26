import 'package:flutter/material.dart';

import '../game/clock.dart';
import '../recording/moments.dart';
import 'draw.dart';
import 'style.dart';

class ResultsView extends StatelessWidget {
  const ResultsView({
    super.key,
    required this.headline,
    required this.score,
    required this.deckName,
    required this.seconds,
    required this.passed,
    required this.bestLabel,
    required this.newBest,
    required this.marks,
    required this.expanded,
    required this.hasRecording,
    required this.onToggle,
    required this.onJump,
    required this.onPlayAgain,
    required this.onNewDeck,
    required this.onHome,
    required this.recording,
    this.reduceMotion = false,
  });

  final String headline;
  final int score;
  final String deckName;
  final int seconds;
  final int passed;
  final String bestLabel;
  final bool newBest;
  final List<RoundMark> marks;
  final int? expanded;
  final bool hasRecording;
  final ValueChanged<int> onToggle;
  final ValueChanged<RoundMark> onJump;
  final VoidCallback onPlayAgain;
  final VoidCallback onNewDeck;
  final VoidCallback onHome;
  final Widget recording;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final left = <RoundMark>[];
    final right = <RoundMark>[];
    for (var i = 0; i < marks.length; i++) {
      (i.isEven ? left : right).add(marks[i]);
    }
    return RingField(
      color: ink,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const Key('home-results'),
                  tooltip: 'Home',
                  onPressed: onHome,
                  icon: const Icon(Icons.home_rounded, color: cream),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(headline, style: condensed(28, color: gold, weight: FontWeight.w900, tracking: 1.5)),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 118,
                            height: 118,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (newBest && !reduceMotion) const Flakes(progress: 0.85, count: 24),
                                Container(
                                  width: 104,
                                  height: 104,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: goldLeaf, width: 8),
                                  ),
                                  child: Text('$score', style: fraunces(56, goldLeaf)),
                                ),
                              ],
                            ),
                          ),
                          Text('GOT IT', style: condensed(16, color: gold, tracking: 1.6)),
                          const SizedBox(height: 8),
                          Text(
                            '${deckName.toUpperCase()} · ${seconds}s · $passed PASSED',
                            style: condensed(14, tracking: 0.6),
                          ),
                          Text(
                            bestLabel,
                            key: const Key('best-line'),
                            style: condensed(16, color: newBest ? goldLeaf : cream, tracking: 1.2),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: GoldButton(
                                  key: const Key('play-again'),
                                  label: 'PLAY AGAIN',
                                  onPressed: onPlayAgain,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LineButton(
                                  key: const Key('new-deck'),
                                  label: 'NEW DECK',
                                  onPressed: onNewDeck,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cream,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: GoldInset(
                          radius: 16,
                          inset: 8,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Row(
                                    key: const Key('round-list'),
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _Column(marks: left, all: marks, expanded: expanded, hasRecording: hasRecording, onToggle: onToggle, onJump: onJump)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _Column(marks: right, all: marks, expanded: expanded, hasRecording: hasRecording, onToggle: onToggle, onJump: onJump)),
                                    ],
                                  ),
                                ),
                                recording,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.marks,
    required this.all,
    required this.expanded,
    required this.hasRecording,
    required this.onToggle,
    required this.onJump,
  });

  final List<RoundMark> marks;
  final List<RoundMark> all;
  final int? expanded;
  final bool hasRecording;
  final ValueChanged<int> onToggle;
  final ValueChanged<RoundMark> onJump;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final mark in marks) _Row(
          mark: mark,
          index: all.indexOf(mark),
          open: expanded == all.indexOf(mark),
          hasRecording: hasRecording,
          onToggle: onToggle,
          onJump: onJump,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.mark,
    required this.index,
    required this.open,
    required this.hasRecording,
    required this.onToggle,
    required this.onJump,
  });

  final RoundMark mark;
  final int index;
  final bool open;
  final bool hasRecording;
  final ValueChanged<int> onToggle;
  final ValueChanged<RoundMark> onJump;

  @override
  Widget build(BuildContext context) {
    final color = mark.correct ? gold : amethyst;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: open ? const Color(0xFFF3E6C4) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => onToggle(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(mark.correct ? Icons.check_circle : Icons.arrow_upward, color: color, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(mark.prompt, style: fraunces(16, navy, weight: 800, height: 1.1)),
                    ),
                    if (!mark.correct && !open)
                      Text('TAP', style: condensed(11, color: amethyst, tracking: 0.8)),
                  ],
                ),
                if (open) ...[
                  const SizedBox(height: 4),
                  Text('“${mark.clue}”', style: fraunces(14, navy, italic: true, weight: 600, height: 1.15)),
                  if (hasRecording)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: Key('jump-${mark.cardId}'),
                        onPressed: () => onJump(mark),
                        child: Text('▶ ${formatMark(mark.tMs)}', style: condensed(14, color: navy, tracking: 0.6)),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecordingStrip extends StatelessWidget {
  const RecordingStrip({
    super.key,
    required this.label,
    required this.onWatch,
    required this.onSave,
    required this.onDelete,
    this.canSave = false,
    this.canDelete = false,
  });

  final String label;
  final VoidCallback? onWatch;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final bool canSave;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(16),
      ),
          child: Row(
            children: [
              const Icon(Icons.play_circle_fill, color: cream, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onWatch,
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: body(13, weight: FontWeight.w600),
                  ),
                ),
              ),
          if (canSave)
            TextButton(
              key: const Key('save-recording'),
              onPressed: onSave,
              child: Text('SAVE', style: condensed(14, color: goldLeaf, tracking: 1)),
            ),
          if (canDelete)
            TextButton(
              key: const Key('delete-recording'),
              onPressed: onDelete,
              child: Text('DELETE', style: condensed(14, tracking: 1)),
            ),
        ],
      ),
    );
  }
}

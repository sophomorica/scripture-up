import 'package:flutter/material.dart';

import '../game/clock.dart';
import 'draw.dart';
import 'style.dart';

class ForeheadView extends StatelessWidget {
  const ForeheadView({
    super.key,
    required this.roundNumber,
    required this.armProgress,
    required this.tapMode,
    required this.recording,
    required this.onStart,
  });

  final int roundNumber;
  final double armProgress;
  final bool tapMode;
  final bool recording;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return RingField(
      color: ink,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Text(
                'ROUND $roundNumber',
                key: const Key('round-label'),
                style: condensed(16, color: cream, tracking: 2.4),
              ),
              const Spacer(),
              Text(
                'Turn sideways. Hold it to your forehead.',
                textAlign: TextAlign.center,
                style: fraunces(36, cream, height: 1.05),
              ),
              const SizedBox(height: 10),
              Text('Screen faces your team.', style: body(18, color: cream.withValues(alpha: 0.8))),
              const SizedBox(height: 28),
              if (tapMode)
                SizedBox(
                  width: 280,
                  child: GoldButton(
                    key: const Key('start-round'),
                    label: 'START',
                    chevron: false,
                    onPressed: onStart,
                  ),
                )
              else
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: armProgress == 0 ? null : armProgress,
                    strokeWidth: 8,
                    color: goldLeaf,
                    backgroundColor: gold.withValues(alpha: 0.25),
                  ),
                ),
              const Spacer(),
              if (recording)
                Text('REC', key: const Key('rec-dot'), style: condensed(14, color: ember, tracking: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class CountdownView extends StatelessWidget {
  const CountdownView({
    super.key,
    required this.roundNumber,
    required this.numeral,
    required this.progress,
    required this.recording,
  });

  final int roundNumber;
  final int numeral;
  final double progress;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    return RingField(
      color: ink,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            children: [
              Row(
                children: [
                  const Spacer(),
                  if (recording)
                    Text('REC', style: condensed(14, color: ember, tracking: 1.4)),
                ],
              ),
              Text('ROUND $roundNumber', key: const Key('round-label'), style: condensed(16, tracking: 2.2)),
              Text('GET READY', style: condensed(14, color: gold, tracking: 2)),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'GUESSER\nHold it to your forehead. Don’t peek.',
                        style: fraunces(22, cream, weight: 800, height: 1.05),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            color: goldLeaf,
                            backgroundColor: gold.withValues(alpha: 0.2),
                          ),
                          Text(
                            '$numeral',
                            key: const Key('countdown'),
                            style: fraunces(120, goldLeaf),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'TEAM\nAct it out. Never say the words.',
                        textAlign: TextAlign.right,
                        style: fraunces(22, cream, weight: 800, height: 1.05),
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

class CardPlayView extends StatelessWidget {
  const CardPlayView({
    super.key,
    required this.color,
    required this.prompt,
    required this.clue,
    required this.got,
    required this.timeLeft,
    required this.deckName,
    required this.recording,
    required this.tapMode,
    required this.urgent,
    required this.urgentFast,
    required this.pauseProgress,
    required this.onCorrect,
    required this.onPass,
    required this.onPauseDown,
    required this.onPauseUp,
    this.reduceMotion = false,
  });

  final Color color;
  final String prompt;
  final String clue;
  final int got;
  final Duration timeLeft;
  final String deckName;
  final bool recording;
  final bool tapMode;
  final bool urgent;
  final bool urgentFast;
  final double pauseProgress;
  final VoidCallback onCorrect;
  final VoidCallback onPass;
  final VoidCallback onPauseDown;
  final VoidCallback onPauseUp;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final timerColor = urgent ? ember : cream;
    return RingField(
      color: color,
      child: GoldInset(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    _Chip(child: Text('$got  GOT', style: condensed(16, color: navy, tracking: 1))),
                    const Spacer(),
                    GestureDetector(
                      onTapDown: (_) => onPauseDown(),
                      onTapUp: (_) => onPauseUp(),
                      onTapCancel: onPauseUp,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (pauseProgress > 0)
                            SizedBox(
                              width: 92,
                              height: 44,
                              child: CircularProgressIndicator(
                                value: pauseProgress,
                                strokeWidth: 3,
                                color: goldLeaf,
                              ),
                            ),
                          Container(
                            key: const Key('round-clock'),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: ink.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: timerColor),
                            ),
                            child: Text(
                              formatClock(timeLeft),
                              style: condensed(
                                urgent ? 28 : 22,
                                color: timerColor,
                                weight: FontWeight.w800,
                                tracking: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (recording) Text('REC  ', style: condensed(13, color: ember, tracking: 1)),
                    Text(deckName.toUpperCase(), style: condensed(14, tracking: 1.2)),
                  ],
                ),
                const Spacer(),
                ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      prompt,
                      key: const Key('card-reference'),
                      style: fraunces(96, cream).copyWith(
                        shadows: const [Shadow(color: navy, offset: Offset(0, 4), blurRadius: 0)],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
                  decoration: BoxDecoration(
                    color: cream,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: navy,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('CLUE', style: condensed(12, color: goldLeaf, tracking: 1)),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '“$clue”',
                          key: const Key('card-clue'),
                          style: fraunces(22, navy, italic: true, weight: 600, height: 1.1),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (tapMode)
                  Row(
                    children: [
                      Expanded(child: _TapFace(key: const Key('pass'), label: 'PASS', color: amethyst, onPressed: onPass)),
                      const SizedBox(width: 12),
                      Expanded(child: _TapFace(key: const Key('got-it'), label: 'GOT IT', color: goldLeaf, onPressed: onCorrect, foreground: navy)),
                    ],
                  )
                else
                  Row(
                    children: [
                      Text('↓ TILT DOWN · GOT IT', style: condensed(13, color: cream.withValues(alpha: 0.7), tracking: 1)),
                      const Spacer(),
                      Text('TILT UP · PASS ↑', style: condensed(13, color: cream.withValues(alpha: 0.7), tracking: 1)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: goldLeaf, borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }
}

class _TapFace extends StatelessWidget {
  const _TapFace({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.foreground = cream,
  });

  final String label;
  final Color color;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(label, style: condensed(28, color: foreground, weight: FontWeight.w900, tracking: 1.4)),
        ),
      ),
    );
  }
}

class CorrectFlashView extends StatelessWidget {
  const CorrectFlashView({
    super.key,
    required this.prompt,
    required this.timeLeft,
    required this.reduceMotion,
  });

  final String prompt;
  final Duration timeLeft;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
      color: goldLeaf,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!reduceMotion) const Sunburst(),
          if (!reduceMotion) const Flakes(progress: 0.7),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(formatClock(timeLeft), style: condensed(22, color: navy, tracking: 1)),
                const Spacer(),
                const CheckDisc(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Got it!', style: fraunces(92, navy, italic: true)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: cream, borderRadius: BorderRadius.circular(16)),
                  child: Text('SCORED  $prompt', style: fraunces(18, navy, weight: 800)),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class PassFlashView extends StatelessWidget {
  const PassFlashView({super.key, required this.prompt, required this.timeLeft});

  final String prompt;
  final Duration timeLeft;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
      color: amethyst,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(formatClock(timeLeft), style: condensed(22, tracking: 1)),
            const Spacer(),
            const UpChevron(color: goldLeaf, size: 54),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('PASS', style: condensed(120, weight: FontWeight.w900, tracking: 4, height: 0.9)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cream),
              ),
              child: Text('SKIPPED  $prompt', style: condensed(18, tracking: 1)),
            ),
            const Spacer(),
          ],
        ),
      ),
      ),
    );
  }
}

class TimeUpView extends StatelessWidget {
  const TimeUpView({super.key, required this.headline, required this.score});

  final String headline;
  final int score;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
      color: cream,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(headline, style: condensed(64, color: navy, weight: FontWeight.w900, tracking: 2)),
            const SizedBox(height: 12),
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: goldLeaf, width: 8),
              ),
              child: Text('$score', style: fraunces(64, gold)),
            ),
            const SizedBox(height: 12),
            Text('Lower the phone', style: body(18, color: navy)),
          ],
        ),
      ),
      ),
    );
  }
}

class PauseScrim extends StatelessWidget {
  const PauseScrim({super.key, required this.onResume, required this.onEnd});

  final VoidCallback onResume;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ink.withValues(alpha: 0.72),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PAUSED', style: condensed(42, weight: FontWeight.w900, tracking: 2)),
            const SizedBox(height: 16),
            SizedBox(width: 240, child: GoldButton(label: 'RESUME', chevron: false, onPressed: onResume)),
            const SizedBox(height: 10),
            TextButton(
              key: const Key('end-round'),
              onPressed: onEnd,
              child: Text('END ROUND', style: condensed(20, tracking: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}

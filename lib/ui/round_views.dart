import 'package:flutter/material.dart';

import '../game/clock.dart';
import '../game/round_controller.dart';
import 'draw.dart';
import 'fit_text.dart';
import 'style.dart';

class ForeheadView extends StatelessWidget {
  const ForeheadView({
    super.key,
    required this.roundNumber,
    required this.armProgress,
    required this.tapMode,
    required this.recording,
    required this.onStart,
    required this.onLeave,
  });

  final int roundNumber;
  final double armProgress;
  final bool tapMode;
  final bool recording;
  final VoidCallback onStart;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return RingField(
      color: ink,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    key: const Key('leave-round'),
                    tooltip: 'Leave round',
                    onPressed: onLeave,
                    icon: const Icon(Icons.close, color: cream),
                  ),
                  Expanded(
                    child: Text(
                      'ROUND $roundNumber',
                      key: const Key('round-label'),
                      textAlign: TextAlign.center,
                      style: condensed(16, color: cream, tracking: 2.4),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const Spacer(),
              Text(
                'Turn sideways. Hold it to your forehead.',
                textAlign: TextAlign.center,
                style: fraunces(36, cream, height: 1.05),
              ),
              const SizedBox(height: 10),
              Text(
                'Your team reads you a phrase. Name the book, chapter, and verse.',
                textAlign: TextAlign.center,
                style: body(18, color: cream.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 20),
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
                  width: 120,
                  height: 120,
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
    this.reduceMotion = false,
  });

  final int roundNumber;
  final int numeral;
  final double progress;
  final bool recording;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final settle = Curves.easeOutCubic.transform((progress / 0.3).clamp(0.0, 1.0));
    final scale = reduceMotion ? 1.0 : 1.3 - 0.3 * settle;
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
                      child: _TeamJob(
                        label: 'TEAM',
                        labelColor: gold,
                        line: 'Read the phrase out loud. Give any hints.',
                        align: CrossAxisAlignment.start,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              color: goldLeaf,
                              backgroundColor: gold.withValues(alpha: 0.2),
                            ),
                          ),
                          Transform.scale(
                            scale: scale,
                            child: Text(
                              '$numeral',
                              key: const Key('countdown'),
                              style: fraunces(120, goldLeaf),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _TeamJob(
                        label: 'NEVER SAY',
                        labelColor: ember,
                        line: 'The book, chapter, or verse.',
                        align: CrossAxisAlignment.end,
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

class _TeamJob extends StatelessWidget {
  const _TeamJob({
    required this.label,
    required this.labelColor,
    required this.line,
    required this.align,
  });

  final String label;
  final Color labelColor;
  final String line;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final end = align == CrossAxisAlignment.end;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: align,
      children: [
        Text(label, style: condensed(16, color: labelColor, tracking: 2)),
        const SizedBox(height: 6),
        Text(
          line,
          textAlign: end ? TextAlign.right : TextAlign.left,
          style: fraunces(22, cream, weight: 800, height: 1.1),
        ),
      ],
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
    this.glow = 0,
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
  final double glow;

  @override
  Widget build(BuildContext context) {
    final timerColor = urgent ? ember : cream;
    return RingField(
      color: color,
      child: Stack(
        fit: StackFit.expand,
        children: [
          EdgeGlow(intensity: glow),
          GoldInset(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                child: Column(
                  children: [
                    SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          _Chip(child: Text('$got  GOT', style: condensed(16, color: navy, tracking: 1))),
                          const Spacer(),
                          GestureDetector(
                            onTapDown: (_) => onPauseDown(),
                            onTapUp: (_) => onPauseUp(),
                            onTapCancel: onPauseUp,
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  key: const Key('round-clock'),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: ink.withValues(alpha: urgent ? 0.6 : 0.35),
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(color: timerColor),
                                  ),
                                  child: Text(
                                    formatClock(timeLeft),
                                    style: condensed(
                                      urgentFast ? 44 : (urgent ? 28 : 22),
                                      color: timerColor,
                                      weight: FontWeight.w800,
                                      tracking: 1,
                                    ),
                                  ),
                                ),
                                if (pauseProgress > 0)
                                  Positioned(
                                    left: -8,
                                    right: -8,
                                    top: -5,
                                    bottom: -5,
                                    child: CircularProgressIndicator(
                                      value: pauseProgress,
                                      strokeWidth: 3,
                                      color: goldLeaf,
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
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: FitText(
                              clue,
                              textKey: const Key('card-clue'),
                              style: fraunces(40, cream, weight: 700, height: 1.12),
                              min: 16,
                              max: 44,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _AnswerLine(reference: prompt),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          const _TiltHint(icon: Icons.arrow_downward_rounded, label: 'TILT DOWN · GOT IT', iconFirst: true),
                          const Spacer(),
                          const _TiltHint(icon: Icons.arrow_upward_rounded, label: 'TILT UP · PASS', iconFirst: false),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 5, 22, 3),
        decoration: BoxDecoration(
          color: ink.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ANSWER', style: condensed(13, color: cream.withValues(alpha: 0.85), tracking: 2.4)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                reference,
                key: const Key('card-reference'),
                style: fraunces(48, goldLeaf, height: 1.05),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TiltHint extends StatelessWidget {
  const _TiltHint({required this.icon, required this.label, required this.iconFirst});

  final IconData icon;
  final String label;
  final bool iconFirst;

  @override
  Widget build(BuildContext context) {
    final dim = cream.withValues(alpha: 0.7);
    final glyph = Icon(icon, size: 16, color: dim);
    final text = Text(label, style: condensed(13, color: dim, tracking: 1));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: iconFirst
          ? [glyph, const SizedBox(width: 4), text]
          : [text, const SizedBox(width: 4), glyph],
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
          height: 72,
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
    this.progress = 1,
  });

  final String prompt;
  final Duration timeLeft;
  final bool reduceMotion;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ms = progress * correctFlash.inMilliseconds;
    final pop = reduceMotion ? 1.0 : 1 + 0.3 * (1 - Curves.easeOut.transform((ms / 150).clamp(0.0, 1.0)));
    return SizedBox.expand(
      child: ColoredBox(
        color: goldLeaf,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Sunburst(degrees: reduceMotion ? 0 : ms * 0.04),
            if (!reduceMotion) Flakes(progress: progress, count: 28, reach: 380, colors: const [navy, cream, deepGold]),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(formatClock(timeLeft), style: condensed(22, color: navy, tracking: 1)),
                  const Spacer(),
                  Transform.scale(
                    scale: pop,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CheckDisc(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Got it!', style: fraunces(92, navy, italic: true)),
                        ),
                      ],
                    ),
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
  const PassFlashView({
    super.key,
    required this.prompt,
    required this.timeLeft,
    this.reduceMotion = false,
    this.progress = 0,
  });

  final String prompt;
  final Duration timeLeft;
  final bool reduceMotion;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ms = progress * passFlash.inMilliseconds;
    final leave = reduceMotion
        ? 0.0
        : Curves.easeIn.transform(((ms - 150) / 450).clamp(0.0, 1.0));
    return SizedBox.expand(
      child: ColoredBox(
        color: amethyst,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(formatClock(timeLeft), style: condensed(22, tracking: 1)),
              const Spacer(),
              Opacity(
                opacity: 1 - leave,
                child: Transform.translate(
                  offset: Offset(0, -56 * leave),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const UpChevron(color: goldLeaf, size: 54),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('PASS', style: condensed(120, weight: FontWeight.w900, tracking: 4, height: 0.9)),
                      ),
                    ],
                  ),
                ),
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
  const TimeUpView({
    super.key,
    required this.headline,
    required this.score,
    this.revealPrompt,
    this.revealClue,
  });

  final String headline;
  final int score;
  final String? revealPrompt;
  final String? revealClue;

  @override
  Widget build(BuildContext context) {
    final prompt = revealPrompt;
    final clue = revealClue;
    final tally = Column(
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
          child: Text('$score', key: const Key('time-up-score'), style: fraunces(64, gold)),
        ),
      ],
    );
    return SizedBox.expand(
      child: ColoredBox(
        color: cream,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: prompt == null || clue == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        tally,
                        const SizedBox(height: 12),
                        Text('Lower the phone', style: body(18, color: navy)),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      Center(child: tally),
                      const SizedBox(width: 28),
                      Expanded(child: _Reveal(prompt: prompt, clue: clue)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.prompt, required this.clue});

  final String prompt;
  final String clue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('IT WAS', textAlign: TextAlign.center, style: condensed(16, color: goldLeaf, tracking: 3)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              prompt,
              key: const Key('reveal-reference'),
              style: fraunces(40, goldLeaf, height: 1.05),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FitText(
              clue,
              textKey: const Key('reveal-clue'),
              style: fraunces(28, cream, weight: 700, height: 1.12),
              min: 12,
              max: 26,
            ),
          ),
        ],
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

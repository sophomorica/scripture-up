import 'package:flutter/material.dart';

import '../game/deck.dart';
import 'draw.dart';
import 'style.dart';

Future<void> showDeckSheet({
  required BuildContext context,
  required Deck deck,
  required Duration length,
  required bool record,
  required bool tapMode,
  required ValueChanged<Duration> onLength,
  required ValueChanged<bool> onRecord,
  required ValueChanged<bool> onTapMode,
  required VoidCallback onPlay,
}) {
  var sheetLength = length;
  var sheetRecord = record;
  var sheetTap = tapMode;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return FractionallySizedBox(
            heightFactor: 0.88,
            child: DeckSheet(
              deck: deck,
              length: sheetLength,
              record: sheetRecord,
              tapMode: sheetTap,
              onLength: (value) {
                sheetLength = value;
                onLength(value);
                setSheet(() {});
              },
              onRecord: (value) {
                sheetRecord = value;
                onRecord(value);
                setSheet(() {});
              },
              onTapMode: (value) {
                sheetTap = value;
                onTapMode(value);
                setSheet(() {});
              },
              onPlay: deck.playable
                  ? () {
                      Navigator.pop(context);
                      onPlay();
                    }
                  : null,
            ),
          );
        },
      );
    },
  );
}

class DeckSheet extends StatelessWidget {
  const DeckSheet({
    super.key,
    required this.deck,
    required this.length,
    required this.record,
    required this.tapMode,
    required this.onLength,
    required this.onRecord,
    required this.onTapMode,
    required this.onPlay,
  });

  final Deck deck;
  final Duration length;
  final bool record;
  final bool tapMode;
  final ValueChanged<Duration> onLength;
  final ValueChanged<bool> onRecord;
  final ValueChanged<bool> onTapMode;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final sample = deck.cards.isEmpty ? null : deck.cards.first;
    return Material(
      color: deck.hero,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: cream.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
            Emblem(name: deck.emblem, size: 42),
            const SizedBox(height: 10),
            Text(deck.name, style: fraunces(36, cream, height: 1)),
            const SizedBox(height: 8),
            Text(deck.pitch, style: body(16)),
            const SizedBox(height: 16),
            if (sample != null)
              Transform.rotate(
                angle: -0.04,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cream,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    sample.prompt,
                    style: fraunces(22, navy, weight: 800),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text('ROUND', style: condensed(13, color: goldLeaf, tracking: 1.6)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final seconds in [30, 60, 90])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('sheet-length-$seconds'),
                      label: Text('${seconds}s'),
                      selected: length.inSeconds == seconds,
                      onSelected: (_) => onLength(Duration(seconds: seconds)),
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              key: const Key('record-team'),
              contentPadding: EdgeInsets.zero,
              title: Text('Record the team', style: body(16, weight: FontWeight.w600)),
              value: record,
              onChanged: onRecord,
            ),
            Text('CONTROLS', style: condensed(13, color: goldLeaf, tracking: 1.6)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Tilt')),
                ButtonSegment(value: true, label: Text('Tap buttons')),
              ],
              selected: {tapMode},
              onSelectionChanged: (value) => onTapMode(value.first),
            ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!deck.playable)
              Text(
                'This deck is not live yet. Book of Mormon is the one you can play.',
                style: body(15),
              )
            else
              GoldButton(key: const Key('sheet-play'), label: 'PLAY', onPressed: onPlay),
          ],
        ),
      ),
    );
  }
}

class AboutSheet extends StatelessWidget {
  const AboutSheet({
    super.key,
    required this.respectSilence,
    required this.onRespectSilence,
    required this.onDebug,
    this.onClose,
    this.theta,
    this.phase,
  });

  final bool respectSilence;
  final ValueChanged<bool> onRespectSilence;
  final VoidCallback onDebug;
  final VoidCallback? onClose;
  final double? theta;
  final String? phase;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ink,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose ?? () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: cream),
                ),
                Text('HOW TO PLAY', style: condensed(18, color: gold, tracking: 1.6)),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onLongPress: onDebug,
              child: Text('Scripture Up', style: fraunces(40, cream)),
            ),
            const SizedBox(height: 12),
            Text(
              'One player holds the phone on their forehead. The screen faces the team.',
              style: body(17),
            ),
            const SizedBox(height: 8),
            Text('Tilt the screen down when the guess is right. Tilt it up to pass.', style: body(17)),
            const SizedBox(height: 8),
            Text(
              'Bring the phone back to level before the next card. Tap buttons are there when tilt is off.',
              style: body(17),
            ),
            const SizedBox(height: 18),
            SwitchListTile(
              key: const Key('respect-silence'),
              contentPadding: EdgeInsets.zero,
              title: Text('Respect the silent switch', style: body(16, weight: FontWeight.w600)),
              value: respectSilence,
              onChanged: onRespectSilence,
            ),
            if (theta != null)
              Text(
                'θ ${theta!.toStringAsFixed(1)}° · ${phase ?? 'neutral'}',
                key: const Key('tilt-debug'),
                style: condensed(18, color: goldLeaf),
              ),
            const SizedBox(height: 24),
            Text(
              'Not affiliated with The Church of Jesus Christ of Latter-day Saints.',
              style: body(14, color: cream.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ),
    );
  }
}

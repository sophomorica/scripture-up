import 'package:flutter/material.dart';

import '../game/scripture_card.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.decks,
    required this.lengths,
    required this.onPlay,
    required this.onOpenLibrary,
  });

  final List<Deck> decks;
  final List<Duration> lengths;
  final void Function(Deck deck, Duration length) onPlay;
  final VoidCallback onOpenLibrary;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Duration _length = widget.lengths.contains(const Duration(seconds: 60))
      ? const Duration(seconds: 60)
      : widget.lengths.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Text(
              'Scripture Up',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: pine,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hold the phone on your forehead. Your team gives the clues.',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(height: 1.3, color: ink.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 22),
            const _HowToPlay(),
            const SizedBox(height: 22),
            Text(
              'Round length',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final length in widget.lengths)
                  ChoiceChip(
                    key: Key('length-${length.inSeconds}'),
                    label: Text('${length.inSeconds} seconds'),
                    selected: length == _length,
                    onSelected: (_) => setState(() => _length = length),
                    selectedColor: pine,
                    labelStyle: TextStyle(
                      color: length == _length ? ivory : ink,
                      fontWeight: FontWeight.w700,
                    ),
                    side: const BorderSide(color: line),
                    backgroundColor: foam,
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Pick a deck',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final deck in widget.decks) ...[
              _DeckTile(
                deck: deck,
                onTap: () {
                  if (!deck.playable) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('That deck is on the way.')),
                    );
                    return;
                  }
                  widget.onPlay(deck, _length);
                },
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('open-recordings'),
              onPressed: widget.onOpenLibrary,
              style: OutlinedButton.styleFrom(
                foregroundColor: pine,
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: pine),
              ),
              child: const Text('Saved recordings'),
            ),
            const SizedBox(height: 22),
            Text(
              'Not affiliated with The Church of Jesus Christ of Latter-day Saints.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: ink.withValues(alpha: 0.62), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowToPlay extends StatelessWidget {
  const _HowToPlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: foam,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How a round works',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text('The screen faces your team. They describe the clue.'),
          SizedBox(height: 4),
          Text('Tilt the screen down when the guess is right.'),
          SizedBox(height: 4),
          Text('Tilt the screen up to pass. The buttons do the same.'),
        ],
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.deck, required this.onTap});

  final Deck deck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final playable = deck.playable;
    return Material(
      color: playable ? Colors.white : paper,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('deck-${deck.id.name}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: playable ? pine : line,
              width: playable ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: playable ? ink : ink.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playable ? '${deck.cards.length} cards' : 'Coming soon',
                      style: TextStyle(
                        color: playable ? moss : ink.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                playable ? Icons.play_arrow_rounded : Icons.hourglass_empty,
                color: playable ? pine : ink.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

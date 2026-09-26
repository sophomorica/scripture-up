import 'dart:math';

import 'package:flutter/material.dart';

import '../game/deck.dart';
import 'draw.dart';
import 'style.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({
    super.key,
    required this.decks,
    required this.length,
    required this.onLength,
    required this.onPlay,
    required this.onOpen,
    required this.onVideos,
    required this.onAbout,
  });

  final List<Deck> decks;
  final Duration length;
  final ValueChanged<Duration> onLength;
  final ValueChanged<Deck> onPlay;
  final ValueChanged<Deck> onOpen;
  final VoidCallback onVideos;
  final VoidCallback onAbout;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  String? _shaking;

  Deck? get _hero => widget.decks.cast<Deck?>().firstWhere(
    (deck) => deck!.playable,
    orElse: () => null,
  );

  List<Deck> _group(List<String> ids) {
    return [
      for (final id in ids)
        ...widget.decks.where((deck) => deck.id == id),
    ];
  }

  void _closed(Deck deck) {
    setState(() => _shaking = deck.id);
    _shake.forward(from: 0).whenComplete(() {
      if (mounted && _shaking == deck.id) {
        setState(() => _shaking = null);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon. Book of Mormon is live.')),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hero = _hero;
    return Scaffold(
      backgroundColor: ink,
      body: RingField(
        color: ink,
        child: SafeArea(
          child: ListView(
            key: const Key('lobby-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                children: [
                  const _Mark(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'SCRIPTURE ', style: condensed(28, weight: FontWeight.w900, tracking: 0.6)),
                              TextSpan(
                                text: 'UP',
                                style: condensed(28, color: goldLeaf, weight: FontWeight.w900, tracking: 0.6),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'NARROW ROAD STUDIOS',
                          style: condensed(11, color: gold, tracking: 1.6),
                        ),
                      ],
                    ),
                  ),
                  _RoundIconButton(
                    key: const Key('open-recordings'),
                    tooltip: 'Saved videos',
                    icon: Icons.videocam_outlined,
                    onPressed: widget.onVideos,
                  ),
                  const SizedBox(width: 8),
                  _RoundIconButton(
                    key: const Key('about'),
                    tooltip: 'How to play',
                    icon: Icons.question_mark_rounded,
                    onPressed: widget.onAbout,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text('ROUND', style: condensed(13, color: gold, tracking: 2)),
                  const Spacer(),
                  _LengthControl(length: widget.length, onChanged: widget.onLength),
                ],
              ),
              const SizedBox(height: 16),
              if (hero != null)
                Transform.rotate(
                  angle: -0.035,
                  child: _HeroCard(
                    deck: hero,
                    onPlay: () => widget.onPlay(hero),
                  ),
                ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Text('THE CANON', style: condensed(13, color: gold, tracking: 2)),
                  const Spacer(),
                  Text('more coming', style: body(13, color: cream.withValues(alpha: 0.7))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final deck in _group(canonDeckIds)) ...[
                    Expanded(
                      child: _DeckTile(
                        deck: deck,
                        shaking: _shaking == deck.id ? _shake : null,
                        onTap: () => _closed(deck),
                      ),
                    ),
                    if (deck != _group(canonDeckIds).last) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Text('PARTY DECKS', style: condensed(13, color: gold, tracking: 2)),
                  const Spacer(),
                  Text('new', style: body(13, color: cream.withValues(alpha: 0.7))),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.2,
                children: [
                  for (final deck in _group(partyDeckIds))
                    _DeckTile(
                      deck: deck,
                      onTap: () => widget.onOpen(deck),
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

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.7)),
      ),
      child: const Center(child: Emblem(name: 'plates', size: 26)),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: cream,
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(icon),
    );
  }
}

class _LengthControl extends StatelessWidget {
  const _LengthControl({required this.length, required this.onChanged});

  final Duration length;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          for (final seconds in [30, 60, 90])
            _LengthChip(
              seconds: seconds,
              selected: length.inSeconds == seconds,
              onTap: () => onChanged(Duration(seconds: seconds)),
            ),
        ],
      ),
    );
  }
}

class _LengthChip extends StatelessWidget {
  const _LengthChip({
    required this.seconds,
    required this.selected,
    required this.onTap,
  });

  final int seconds;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$seconds seconds',
      child: GestureDetector(
        key: Key('length-$seconds'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? goldLeaf : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${seconds}s',
            style: condensed(
              16,
              color: selected ? navy : cream.withValues(alpha: 0.75),
              weight: FontWeight.w800,
              tracking: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.deck, required this.onPlay});

  final Deck deck;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return GoldInset(
      radius: 28,
      child: Container(
        decoration: BoxDecoration(
          color: deck.hero,
          borderRadius: BorderRadius.circular(32),
        ),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Emblem(name: 'plates', size: 28),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: goldLeaf,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('LIVE', style: condensed(12, color: navy, tracking: 1.2)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(deck.name, style: fraunces(46, cream, height: 0.9)),
            const SizedBox(height: 8),
            Text(
              '${deck.cardCount} CARDS · REFERENCE + CLUE',
              style: condensed(13, tracking: 1.1),
            ),
            const SizedBox(height: 16),
            GoldButton(key: const Key('play-hero'), label: 'PLAY', onPressed: onPlay),
          ],
        ),
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.deck, required this.onTap, this.shaking});

  final Deck deck;
  final VoidCallback onTap;
  final Animation<double>? shaking;

  @override
  Widget build(BuildContext context) {
    final closed = deck.status == DeckStatus.soon;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Emblem(name: deck.emblem, size: 22),
          const SizedBox(height: 6),
          Text(
            deck.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: fraunces(16, cream, weight: 800, height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            closed ? 'COMING SOON' : '${deck.cardCount} CARDS',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: condensed(11, tracking: 0.6),
          ),
          if (!closed)
            Align(
              alignment: Alignment.centerRight,
              child: Text('NEW', style: condensed(11, color: goldLeaf, tracking: 0.8)),
            ),
        ],
      ),
    );
    final tile = Material(
      color: deck.hero,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('deck-${deck.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: closed ? Hatch(child: body) : body,
      ),
    );
    final animation = shaking;
    if (animation == null) {
      return tile;
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final wave = sin(animation.value * pi * 6);
        return Transform.translate(offset: Offset(wave * 6, 0), child: child);
      },
      child: tile,
    );
  }
}

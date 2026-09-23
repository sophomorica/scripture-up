class ScriptureCard {
  const ScriptureCard({
    required this.id,
    required this.reference,
    required this.clue,
  });

  final String id;
  final String reference;
  final String clue;
}

enum DeckId { bookOfMormon, doctrineAndCovenants, oldTestament, newTestament }

class Deck {
  const Deck({required this.id, required this.title, required this.cards});

  final DeckId id;
  final String title;
  final List<ScriptureCard> cards;

  bool get playable => cards.isNotEmpty;
}

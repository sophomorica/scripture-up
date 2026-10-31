import 'dart:convert';
import 'dart:ui';

enum DeckFormat { reference, answer }

enum DeckStatus { live, soon, proposed }

class GameCard {
  const GameCard({
    required this.id,
    required this.clue,
    this.reference,
    this.answer,
    this.difficulty = 2,
  });

  final String id;
  final String? reference;
  final String? answer;
  final String clue;
  final int difficulty;

  String get prompt => reference ?? answer ?? '';

  bool clueLeaks() {
    final clueText = clue.toLowerCase();
    final referenceText = reference;
    if (referenceText != null &&
        referenceText.isNotEmpty &&
        clueText.contains(referenceText.toLowerCase())) {
      return true;
    }
    final answerText = answer;
    if (answerText == null) {
      return false;
    }
    for (final word in answerText.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      if (word.length < 3 || _stopWords.contains(word)) {
        continue;
      }
      if (RegExp('\\b$word\\b').hasMatch(clueText)) {
        return true;
      }
    }
    return false;
  }
}

class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.pitch,
    required this.hero,
    required this.emblem,
    required this.format,
    required this.status,
    required this.cards,
  });

  final String id;
  final String name;
  final String pitch;
  final Color hero;
  final String emblem;
  final DeckFormat format;
  final DeckStatus status;
  final List<GameCard> cards;

  bool get playable => status == DeckStatus.live && cards.isNotEmpty;

  int get cardCount => cards.length;
}

Deck parseDeck(String source) {
  final json = jsonDecode(source) as Map<String, Object?>;
  final cards = (json['cards'] as List<Object?>).map((entry) {
    final card = entry! as Map<String, Object?>;
    return GameCard(
      id: card['id']! as String,
      reference: card['reference'] as String?,
      answer: card['answer'] as String?,
      clue: card['clue']! as String,
      difficulty: card['difficulty'] as int? ?? 2,
    );
  }).toList();
  return Deck(
    id: json['id']! as String,
    name: json['name']! as String,
    pitch: json['pitch']! as String,
    hero: _color(json['heroColor']! as String),
    emblem: json['emblem']! as String,
    format: json['format'] == 'answer'
        ? DeckFormat.answer
        : DeckFormat.reference,
    status: switch (json['status']) {
      'live' => DeckStatus.live,
      'soon' => DeckStatus.soon,
      _ => DeckStatus.proposed,
    },
    cards: cards,
  );
}

const _stopWords = {
  'the',
  'and',
  'for',
  'with',
  'his',
  'her',
  'its',
  'their',
  'from',
  'that',
  'this',
  'those',
  'these',
  'who',
  'was',
  'were',
  'are',
  'not',
  'but',
  'you',
  'your',
  'into',
  'over',
  'they',
  'them',
};

Color _color(String hex) {
  final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
  return Color(0xFF000000 | value);
}

const deckAssetPaths = [
  'assets/decks/bom.json',
  'assets/decks/dc.json',
  'assets/decks/ot.json',
  'assets/decks/nt.json',
  'assets/decks/people.json',
  'assets/decks/places.json',
  'assets/decks/stories.json',
  'assets/decks/objects.json',
  'assets/decks/heroes.json',
  'assets/decks/parables.json',
  'assets/decks/kids.json',
  'assets/decks/hard.json',
];

const canonDeckIds = ['dc', 'ot', 'nt'];

const partyDeckIds = [
  'people',
  'places',
  'stories',
  'objects',
  'heroes',
  'parables',
  'kids',
  'hard',
];

/// Books the lobby picker offers, in canon order. `all` shuffles every book.
const bookPickerIds = ['all', 'ot', 'nt', 'bom', 'dc'];

const bookPickerLabels = {
  'all': 'ALL',
  'ot': 'OT',
  'nt': 'NT',
  'bom': 'BOM',
  'dc': 'D&C',
};

/// The playable deck for a book picker choice. A single book is opened even
/// when its deck JSON still says `soon`; `all` merges every book's cards.
Deck? bookDeck(List<Deck> decks, String bookId) {
  Deck open(Deck d, {String? id, String? name, String? pitch, List<GameCard>? cards}) => Deck(
        id: id ?? d.id,
        name: name ?? d.name,
        pitch: pitch ?? d.pitch,
        hero: d.hero,
        emblem: d.emblem,
        format: d.format,
        status: DeckStatus.live,
        cards: cards ?? d.cards,
      );
  final books = [
    for (final id in const ['ot', 'nt', 'bom', 'dc']) ...decks.where((d) => d.id == id),
  ];
  if (bookId == 'all') {
    if (books.isEmpty) return null;
    final base = books.firstWhere((d) => d.id == 'bom', orElse: () => books.first);
    return open(
      base,
      id: 'all',
      name: 'All Books',
      pitch: 'Every book, shuffled together.',
      cards: [for (final d in books) ...d.cards],
    );
  }
  final match = books.where((d) => d.id == bookId);
  if (match.isEmpty || match.first.cards.isEmpty) return null;
  return open(match.first);
}

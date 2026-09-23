import 'scripture_card.dart';

const bookOfMormonDeck = Deck(
  id: DeckId.bookOfMormon,
  title: 'Book of Mormon',
  cards: [
    ScriptureCard(
      id: 'bom-1ne-3-7',
      reference: '1 Nephi 3:7',
      clue: 'I will go and do',
    ),
    ScriptureCard(
      id: 'bom-1ne-1-1',
      reference: '1 Nephi 1:1',
      clue: 'Born of goodly parents',
    ),
    ScriptureCard(
      id: 'bom-2ne-2-25',
      reference: '2 Nephi 2:25',
      clue: 'That they might have joy',
    ),
    ScriptureCard(
      id: 'bom-2ne-9-28',
      reference: '2 Nephi 9:28',
      clue: 'Learned, yet not wise',
    ),
    ScriptureCard(
      id: 'bom-mos-2-17',
      reference: 'Mosiah 2:17',
      clue: 'Service to other people',
    ),
    ScriptureCard(
      id: 'bom-alma-32-21',
      reference: 'Alma 32:21',
      clue: 'Hope in what is not seen',
    ),
    ScriptureCard(
      id: 'bom-alma-37-6',
      reference: 'Alma 37:6',
      clue: 'Small and simple things',
    ),
    ScriptureCard(
      id: 'bom-hel-5-12',
      reference: 'Helaman 5:12',
      clue: 'A foundation on the rock',
    ),
    ScriptureCard(
      id: 'bom-3ne-11-10',
      reference: '3 Nephi 11:10',
      clue: 'He speaks his own name',
    ),
    ScriptureCard(
      id: 'bom-ether-12-27',
      reference: 'Ether 12:27',
      clue: 'Weakness made strong',
    ),
    ScriptureCard(
      id: 'bom-moro-10-4',
      reference: 'Moroni 10:4',
      clue: 'Ask if it is true',
    ),
    ScriptureCard(
      id: 'bom-1ne-16-10',
      reference: '1 Nephi 16:10',
      clue: 'A ball of curious workmanship',
    ),
    ScriptureCard(
      id: 'bom-mos-3-19',
      reference: 'Mosiah 3:19',
      clue: 'Yield like a child',
    ),
    ScriptureCard(
      id: 'bom-alma-7-11',
      reference: 'Alma 7:11',
      clue: 'Pains and sicknesses',
    ),
    ScriptureCard(
      id: 'bom-2ne-31-20',
      reference: '2 Nephi 31:20',
      clue: 'Press forward',
    ),
    ScriptureCard(
      id: 'bom-moro-7-47',
      reference: 'Moroni 7:47',
      clue: 'Pure love',
    ),
    ScriptureCard(
      id: 'bom-enos-1-4',
      reference: 'Enos 1:4',
      clue: 'A wrestle in prayer',
    ),
    ScriptureCard(
      id: 'bom-mos-4-9',
      reference: 'Mosiah 4:9',
      clue: 'He has all wisdom',
    ),
  ],
);

const doctrineAndCovenantsDeck = Deck(
  id: DeckId.doctrineAndCovenants,
  title: 'Doctrine and Covenants',
  cards: [],
);

const oldTestamentDeck = Deck(
  id: DeckId.oldTestament,
  title: 'Old Testament',
  cards: [],
);

const newTestamentDeck = Deck(
  id: DeckId.newTestament,
  title: 'New Testament',
  cards: [],
);

const scriptureDecks = [
  bookOfMormonDeck,
  doctrineAndCovenantsDeck,
  oldTestamentDeck,
  newTestamentDeck,
];

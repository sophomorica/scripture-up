import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/deck.dart';
import 'package:scripture_up/ui/fit_text.dart';
import 'package:scripture_up/ui/round_views.dart';
import 'package:scripture_up/ui/style.dart';

import 'support/app_fonts.dart';

class Face {
  const Face(this.size, this.padding);

  final Size size;
  final EdgeInsets padding;

  Rect get safe => Rect.fromLTRB(
    padding.left,
    padding.top,
    size.width - padding.right,
    size.height - padding.bottom,
  );
}

const faces = [
  Face(Size(812, 375), EdgeInsets.fromLTRB(50, 0, 50, 21)),
  Face(Size(844, 390), EdgeInsets.fromLTRB(47, 0, 47, 21)),
];

List<(Deck, GameCard)> liveCards() {
  final cards = <(Deck, GameCard)>[];
  for (final id in ['bom', 'ot', 'nt', 'dc']) {
    final deck = parseDeck(File('assets/decks/$id.json').readAsStringSync());
    for (final card in deck.cards) {
      cards.add((deck, card));
    }
  }
  return cards;
}

Future<void> pumpFace(WidgetTester tester, Face face, Widget view) async {
  await tester.binding.setSurfaceSize(face.size);
  tester.view.physicalSize = face.size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: scriptureTheme(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: face.padding),
          child: Scaffold(backgroundColor: ink, body: view),
        ),
      ),
    ),
  );
}

double fontSizeOf(WidgetTester tester, Key key) {
  return tester.widget<Text>(find.byKey(key)).style!.fontSize!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets('all 100 live cards fit the card face at phone sizes in tilt and tap mode', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cards = liveCards();
    expect(cards, hasLength(100));

    var smallestPhrase = double.infinity;
    var smallestAnswer = double.infinity;
    for (final face in faces) {
      for (final tap in [false, true]) {
        for (final (deck, card) in cards) {
          final label = '${card.id} ${face.size} ${tap ? 'tap' : 'tilt'}';
          await pumpFace(
            tester,
            face,
            CardPlayView(
              color: deck.hero,
              prompt: card.prompt,
              clue: card.clue,
              got: 12,
              timeLeft: const Duration(seconds: 5),
              deckName: deck.name,
              recording: true,
              tapMode: tap,
              urgent: true,
              urgentFast: true,
              pauseProgress: 0,
              onCorrect: () {},
              onPass: () {},
              onPauseDown: () {},
              onPauseUp: () {},
            ),
          );
          expect(tester.takeException(), isNull, reason: label);

          final clueText = tester.widget<Text>(find.byKey(const Key('card-clue')));
          final refText = tester.widget<Text>(find.byKey(const Key('card-reference')));
          expect(clueText.data, card.clue, reason: label);
          expect(refText.data, card.prompt, reason: label);
          expect(clueText.overflow, isNot(TextOverflow.ellipsis), reason: label);
          expect(refText.overflow, isNot(TextOverflow.ellipsis), reason: label);

          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(const Key('card-clue')),
              matching: find.byType(RichText),
            ),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          expect(paragraph.overflow, isNot(TextOverflow.ellipsis), reason: label);

          final fit = tester.getRect(find.byType(FitText));
          final clue = tester.getRect(find.byKey(const Key('card-clue')));
          final answer = tester.getRect(find.byKey(const Key('card-reference')));
          expect(fit.inflate(0.5).contains(clue.topLeft), isTrue, reason: label);
          expect(fit.inflate(0.5).contains(clue.bottomRight), isTrue, reason: label);
          expect(clue.bottom, lessThanOrEqualTo(answer.top), reason: label);
          expect(face.safe.inflate(0.5).contains(clue.topLeft), isTrue, reason: label);
          expect(face.safe.inflate(0.5).contains(clue.bottomRight), isTrue, reason: label);
          expect(face.safe.inflate(0.5).contains(answer.topLeft), isTrue, reason: label);
          expect(face.safe.inflate(0.5).contains(answer.bottomRight), isTrue, reason: label);

          final phrasePt = fontSizeOf(tester, const Key('card-clue'));
          final answerPt = 48 * answer.width / tester.getSize(find.descendant(
            of: find.byKey(const Key('card-reference')),
            matching: find.byType(RichText),
          )).width;
          smallestPhrase = phrasePt < smallestPhrase ? phrasePt : smallestPhrase;
          smallestAnswer = answerPt < smallestAnswer ? answerPt : smallestAnswer;
          expect(phrasePt, greaterThanOrEqualTo(20), reason: label);
          expect(answerPt, greaterThanOrEqualTo(40), reason: label);
        }
      }
    }
    expect(smallestPhrase, greaterThanOrEqualTo(20));
  });

  testWidgets('the longest phrase and the typical phrase get the sizes the layout promises', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cards = liveCards();
    final longest = cards.reduce(
      (a, b) => a.$2.clue.length >= b.$2.clue.length ? a : b,
    );
    expect(longest.$2.id, 'dc-d-c-121-36-41-42');
    final typical = cards.firstWhere((entry) => entry.$2.clue.length == 60);

    final sizes = <String, double>{};
    for (final face in faces) {
      for (final tap in [false, true]) {
        for (final (name, (deck, card)) in [('longest', longest), ('typical', typical)]) {
          await pumpFace(
            tester,
            face,
            CardPlayView(
              color: deck.hero,
              prompt: card.prompt,
              clue: card.clue,
              got: 0,
              timeLeft: const Duration(seconds: 30),
              deckName: deck.name,
              recording: false,
              tapMode: tap,
              urgent: false,
              urgentFast: false,
              pauseProgress: 0,
              onCorrect: () {},
              onPass: () {},
              onPauseDown: () {},
              onPauseUp: () {},
            ),
          );
          sizes['$name ${face.size.width.toInt()} ${tap ? 'tap' : 'tilt'}'] =
              fontSizeOf(tester, const Key('card-clue'));
        }
      }
    }
    expect(sizes['typical 812 tilt'], 44);
    expect(sizes['typical 812 tap'], 44);
    expect(sizes['typical 844 tilt'], 44);
    expect(sizes['longest 812 tilt'], greaterThanOrEqualTo(30));
    expect(sizes['longest 812 tap'], greaterThanOrEqualTo(22));
    expect(sizes['longest 844 tilt'], greaterThanOrEqualTo(30));
  });

  testWidgets('the time-up reveal fits every live card at phone sizes', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var smallest = double.infinity;
    for (final face in faces) {
      for (final (_, card) in liveCards()) {
        final label = '${card.id} ${face.size}';
        await pumpFace(
          tester,
          face,
          TimeUpView(
            headline: 'DECK CLEARED',
            score: 29,
            revealPrompt: card.prompt,
            revealClue: card.clue,
          ),
        );
        expect(tester.takeException(), isNull, reason: label);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const Key('reveal-clue')),
            matching: find.byType(RichText),
          ),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        final clue = tester.getRect(find.byKey(const Key('reveal-clue')));
        final reference = tester.getRect(find.byKey(const Key('reveal-reference')));
        expect(face.safe.inflate(0.5).contains(clue.topLeft), isTrue, reason: label);
        expect(face.safe.inflate(0.5).contains(clue.bottomRight), isTrue, reason: label);
        expect(reference.bottom, lessThanOrEqualTo(clue.top), reason: label);
        final pt = fontSizeOf(tester, const Key('reveal-clue'));
        smallest = pt < smallest ? pt : smallest;
        expect(pt, greaterThanOrEqualTo(14), reason: label);
      }
    }
    expect(smallest, greaterThanOrEqualTo(14));
  });
}

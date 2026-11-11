import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/ui/draw.dart';
import 'package:scripture_up/ui/round_views.dart';
import 'package:scripture_up/ui/style.dart';

import 'support/app_fonts.dart';
import 'widget_test.dart' show beginCard, pumpGame, startTapRound;

CardPlayView cardAt(Duration left, {required bool urgent, required bool fast}) {
  return CardPlayView(
    color: const Color(0xFF1F4BA5),
    prompt: '1 Nephi 3:7',
    clue: '“I will go and do the things which the Lord hath commanded.”',
    got: 2,
    timeLeft: left,
    deckName: 'Book of Mormon',
    recording: false,
    tapMode: false,
    urgent: urgent,
    urgentFast: fast,
    pauseProgress: 0,
    onCorrect: () {},
    onPass: () {},
    onPauseDown: () {},
    onPauseUp: () {},
  );
}

double clockSize(WidgetTester tester) {
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const Key('round-clock')),
          matching: find.byType(Text),
        ),
      )
      .style!
      .fontSize!;
}

double glow(WidgetTester tester) => tester.widget<EdgeGlow>(find.byType(EdgeGlow)).intensity;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets('the clock grows to 44 in the last five seconds without moving the phrase', (tester) async {
    await tester.binding.setSurfaceSize(const Size(812, 375));
    tester.view.physicalSize = const Size(812, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpCard(Widget view) {
      return tester.pumpWidget(
        MaterialApp(theme: scriptureTheme(), home: Scaffold(body: view)),
      );
    }

    await pumpCard(cardAt(const Duration(seconds: 40), urgent: false, fast: false));
    expect(clockSize(tester), 22);
    final phrase = tester.getRect(find.byKey(const Key('card-clue')));
    final answer = tester.getRect(find.byKey(const Key('card-reference')));
    await pumpCard(cardAt(const Duration(seconds: 8), urgent: true, fast: false));
    expect(clockSize(tester), 28);
    await pumpCard(cardAt(const Duration(seconds: 4), urgent: true, fast: true));
    expect(clockSize(tester), 44);
    expect(tester.getRect(find.byKey(const Key('card-clue'))), phrase);
    expect(tester.getRect(find.byKey(const Key('card-reference'))), answer);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the screen edges pulse ember once a second in the last ten, twice in the last five', (tester) async {
    await pumpGame(tester);
    await startTapRound(tester);
    await beginCard(tester);
    expect(glow(tester), 0);

    await tester.pump(const Duration(seconds: 20, milliseconds: 10));
    expect(glow(tester), greaterThan(0.95));
    await tester.pump(const Duration(milliseconds: 500));
    expect(glow(tester), closeTo(0.25, 0.05));
    await tester.pump(const Duration(milliseconds: 480));
    expect(glow(tester), lessThan(0.05));
    await tester.pump(const Duration(milliseconds: 20));
    expect(glow(tester), greaterThan(0.9));

    await tester.pump(const Duration(milliseconds: 4000));
    expect(glow(tester), greaterThan(0.9));
    await tester.pump(const Duration(milliseconds: 250));
    expect(glow(tester), closeTo(0.25, 0.1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(glow(tester), greaterThan(0.9));

    await tester.tap(find.byKey(const Key('got-it')));
    await tester.pump();
    expect(find.text('Got it!'), findsOneWidget);
    expect(glow(tester), greaterThan(0));
  });

  testWidgets('with reduce motion the edges glow steadily instead of pulsing', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpGame(tester);
    await startTapRound(tester);
    await beginCard(tester);
    expect(glow(tester), 0);

    await tester.pump(const Duration(seconds: 20, milliseconds: 10));
    final first = glow(tester);
    expect(first, greaterThan(0));
    expect(first, lessThan(0.5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(glow(tester), first);
    await tester.pump(const Duration(milliseconds: 5000));
    expect(glow(tester), first);
  });
}

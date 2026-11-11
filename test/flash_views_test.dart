import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/ui/draw.dart';
import 'package:scripture_up/ui/round_views.dart';
import 'package:scripture_up/ui/style.dart';

import 'support/app_fonts.dart';
import 'widget_test.dart' show beginCard, pumpGame, startTapRound;

Future<void> pumpFlash(WidgetTester tester, Widget view) async {
  await tester.binding.setSurfaceSize(const Size(812, 375));
  tester.view.physicalSize = const Size(812, 375);
  tester.view.devicePixelRatio = 1;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: scriptureTheme(), home: Scaffold(body: view)),
  );
}

Widget correct(double progress, {bool reduce = false}) => CorrectFlashView(
  prompt: '1 Nephi 3:7',
  timeLeft: const Duration(seconds: 40),
  reduceMotion: reduce,
  progress: progress,
);

Widget pass(double progress, {bool reduce = false}) => PassFlashView(
  prompt: 'Alma 34:9–10',
  timeLeft: const Duration(seconds: 40),
  reduceMotion: reduce,
  progress: progress,
);

double popWidth(WidgetTester tester) => tester.getRect(find.text('Got it!')).width;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets('got it pops from 1.3x to 1x in the first 150 ms and the confetti flies out and fades', (tester) async {
    await pumpFlash(tester, correct(0));
    final start = popWidth(tester);
    await pumpFlash(tester, correct(150 / 700));
    final landed = popWidth(tester);
    await pumpFlash(tester, correct(1));
    final rest = popWidth(tester);
    expect(start / rest, closeTo(1.3, 0.01));
    expect(landed / rest, closeTo(1.0, 0.01));

    await pumpFlash(tester, correct(75 / 700));
    final mid = popWidth(tester) / rest;
    expect(mid, greaterThan(1.0));
    expect(mid, lessThan(1.3));

    await pumpFlash(tester, correct(0.3));
    final early = tester.widget<Flakes>(find.byType(Flakes));
    await pumpFlash(tester, correct(0.9));
    final late = tester.widget<Flakes>(find.byType(Flakes));
    expect(late.progress, greaterThan(early.progress));
  });

  testWidgets('the sunburst turns as the flash runs', (tester) async {
    await pumpFlash(tester, correct(0));
    final first = tester.widget<Sunburst>(find.byType(Sunburst)).degrees;
    await pumpFlash(tester, correct(1));
    final last = tester.widget<Sunburst>(find.byType(Sunburst)).degrees;
    expect(last, greaterThan(first));
    expect(last - first, lessThan(45));
  });

  testWidgets('with reduce motion the got-it flash is one still frame', (tester) async {
    await pumpFlash(tester, correct(0, reduce: true));
    final first = tester.getRect(find.text('Got it!'));
    expect(find.byType(Flakes), findsNothing);
    final burst = tester.widget<Sunburst>(find.byType(Sunburst)).degrees;
    await pumpFlash(tester, correct(0.5, reduce: true));
    expect(tester.getRect(find.text('Got it!')), first);
    expect(tester.widget<Sunburst>(find.byType(Sunburst)).degrees, burst);
    expect(find.byType(Flakes), findsNothing);
  });

  testWidgets('pass holds a beat, then PASS and its chevron slide up and fade', (tester) async {
    await pumpFlash(tester, pass(0));
    final home = tester.getTopLeft(find.text('PASS'));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);

    await pumpFlash(tester, pass(120 / 600));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(tester.getTopLeft(find.text('PASS')), home);

    await pumpFlash(tester, pass(0.9));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(0.5));
    expect(tester.getTopLeft(find.text('PASS')).dy, lessThan(home.dy));
    expect(find.text('SKIPPED  Alma 34:9–10'), findsOneWidget);
  });

  testWidgets('with reduce motion the pass flash is one still frame', (tester) async {
    await pumpFlash(tester, pass(0, reduce: true));
    final home = tester.getTopLeft(find.text('PASS'));
    await pumpFlash(tester, pass(0.9, reduce: true));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(tester.getTopLeft(find.text('PASS')), home);
  });

  testWidgets('the round screen feeds the flash its elapsed time and honours the reduce motion setting', (tester) async {
    await pumpGame(tester);
    await startTapRound(tester);
    await beginCard(tester);
    await tester.tap(find.byKey(const Key('got-it')));
    await tester.pump();
    final landing = popWidth(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Flakes), findsOneWidget);
    expect(popWidth(tester), lessThan(landing));
    await tester.pump(const Duration(milliseconds: 500));

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.tap(find.byKey(const Key('got-it')));
    await tester.pump();
    final still = tester.getRect(find.text('Got it!'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Flakes), findsNothing);
    expect(tester.getRect(find.text('Got it!')), still);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('pass')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });
}

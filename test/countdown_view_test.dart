import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/ui/round_views.dart';
import 'package:scripture_up/ui/style.dart';

import 'support/app_fonts.dart';

Future<void> pumpCountdown(
  WidgetTester tester, {
  double progress = 0,
  bool reduce = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(812, 375));
  tester.view.physicalSize = const Size(812, 375);
  tester.view.devicePixelRatio = 1;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: scriptureTheme(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.fromLTRB(50, 0, 50, 21),
          ),
          child: Scaffold(
            body: CountdownView(
              roundNumber: 1,
              numeral: 3,
              progress: progress,
              recording: false,
              reduceMotion: reduce,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets('the ring fills the dial and sweeps around the numeral', (tester) async {
    await pumpCountdown(tester, progress: 0.4);
    expect(tester.takeException(), isNull);
    final ring = tester.getRect(find.byType(CircularProgressIndicator));
    final numeral = tester.getRect(find.byKey(const Key('countdown')));
    expect(ring.width, 220);
    expect(ring.height, 220);
    expect(ring.contains(numeral.topLeft), isTrue);
    expect(ring.contains(numeral.bottomRight), isTrue);
    expect((ring.center - numeral.center).distance, lessThan(8));
    expect(tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value, 0.4);

    await pumpCountdown(tester, progress: 0.9);
    expect(tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value, 0.9);
  });

  testWidgets('the numeral lands from 1.3x to 1x on each beat', (tester) async {
    await pumpCountdown(tester, progress: 0.9);
    final rest = tester.getRect(find.byKey(const Key('countdown'))).height;
    await pumpCountdown(tester, progress: 0);
    expect(tester.getRect(find.byKey(const Key('countdown'))).height / rest, closeTo(1.3, 0.01));
    await pumpCountdown(tester, progress: 0.1);
    final mid = tester.getRect(find.byKey(const Key('countdown'))).height / rest;
    expect(mid, greaterThan(1.0));
    expect(mid, lessThan(1.3));
    await pumpCountdown(tester, progress: 0.3);
    expect(tester.getRect(find.byKey(const Key('countdown'))).height / rest, closeTo(1.0, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with reduce motion the numeral does not scale', (tester) async {
    await pumpCountdown(tester, progress: 0, reduce: true);
    final first = tester.getRect(find.byKey(const Key('countdown')));
    await pumpCountdown(tester, progress: 0.1, reduce: true);
    expect(tester.getRect(find.byKey(const Key('countdown'))), first);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/links/cross_promo.dart';
import 'package:scripture_up/ui/sheets.dart';
import 'package:scripture_up/ui/style.dart';

void main() {
  test('the Sidekick link carries the hub UTM scheme for in-app strips', () {
    expect(sidekickPromoUri.scheme, 'https');
    expect(sidekickPromoUri.host, 'seminarysidekick.com');
    expect(sidekickPromoUri.queryParameters, {
      'utm_source': 'scripture-up',
      'utm_medium': 'promo-strip',
      'utm_campaign': 'ecosystem-strip',
      'utm_content': 'sidekick',
    });
  });

  testWidgets('about shows the Sidekick strip and its button opens the link', (tester) async {
    var opened = 0;
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: scriptureTheme(),
        home: AboutSheet(respectSilence: true, onRespectSilence: (_) {}, onDebug: () {}, onSidekick: () => opened++),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('sidekick-strip')), findsOneWidget);
    expect(find.text('Seminary Sidekick'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sidekick-open')));
    expect(opened, 1);
    expect(find.text('Not affiliated with The Church of Jesus Christ of Latter-day Saints.'), findsOneWidget);
  });
}

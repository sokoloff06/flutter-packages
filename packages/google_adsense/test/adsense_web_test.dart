// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Run locally with flutter test --platform=chrome

@TestOn('chrome')
library;

import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_adsense/google_adsense.dart';
import 'package:web/web.dart' as web;

void main() {
  const String testClient = 'test_client';
  const String testSlot = 'test_slot';

  setUp(() {
    Adsense.resetForTesting();
  });

  test('Singleton instance', () {
    final Adsense instance1 = Adsense();
    final Adsense instance2 = Adsense();
    expect(instance1, same(instance2));
  });

  test('Repeated initialization throws error', () {
    Adsense().initialize('test-client');
    expect(
        () => Adsense().initialize('test-client'), throwsA(isA<StateError>()));
  });

  test('Initialization adds AdSense snippet to index.html', () {
    // Given
    const String expectedScriptUrl =
        'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-$testClient';

    // When
    Adsense().initialize(testClient);

    // Then
    final web.HTMLScriptElement injected =
        web.document.head!.lastChild! as web.HTMLScriptElement;
    expect(injected.src, expectedScriptUrl);
    expect(injected.crossOrigin, 'anonymous');
    expect(injected.async, true);
  });

  testWidgets('AdUnitWidget is created (not checking rendering)',
      (WidgetTester tester) async {
    // When
    Adsense().initialize(testClient);
    final Widget adUnitWidget = Adsense().adUnit(adSlot: testSlot);
    await tester.pumpWidget(adUnitWidget);
    expect(find.byWidget(adUnitWidget), findsOneWidget);

    // Then
    // final web.HTMLElement? insElement =
    //     web.document.querySelector('flt-platform-view') as web.HTMLElement?;
    // expect(insElement, isNotNull);
    // expect(adUnitWidget, isA<AdUnitWidget>());
    // expect(insElement!.style.display, 'block');
  });

  test(
      'Client passed to widget is used for this widget instead of client passed on initialization',
      () {
    // Given
    const String initClient = 'client1';
    const String widgetClient = 'client2';

    // When
    Adsense().initialize(initClient);
    final AdUnitWidget adUnitWidget1 =
        Adsense().adUnit(adSlot: testSlot, adClient: widgetClient);
    final AdUnitWidget adUnitWidget2 = Adsense().adUnit(adSlot: testSlot);

    // Then
    expect(adUnitWidget1.adClient, widgetClient);
    expect(adUnitWidget2.adClient, initClient);
  });
}

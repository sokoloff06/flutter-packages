// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../google_adsense.dart';
import 'js_interop/adsbygoogle.dart';

/// Widget displaying an ad unit
class AdUnitWidget extends StatefulWidget {
  /// Constructs [AdUnitWidget]
  AdUnitWidget._internal(
    String adClient, {
    required bool isAdTest,
    required Map<String, String> unitParams,
  })  : _adClient = adClient,
        _isAdTest = isAdTest,
        _unitParams = unitParams {
    final Map<String, String> dataAttrs = <String, String>{
      AdUnitParams.AD_CLIENT: 'ca-pub-$_adClient',
      if (_isAdTest) AdUnitParams.AD_TEST: 'on',
      ..._unitParams
    };
    for (final String key in dataAttrs.keys) {
      _insElement.dataset.setProperty(key.toJS, dataAttrs[key]!.toJS);
    }
  }

  /// Creates [AdUnitWidget] from [AdUnitConfiguration] object
  AdUnitWidget.fromConfig(String adClient, AdUnitConfiguration unitConfig)
      : this._internal(adClient,
            isAdTest: unitConfig.isAdTest, unitParams: unitConfig.params);

  final String _adClient;

  final bool _isAdTest;

  final Map<String, String> _unitParams;

  final web.HTMLElement _insElement =
      (web.document.createElement('ins') as web.HTMLElement)
        ..className = 'adsbygoogle'
        ..style.display = 'block';

  @override
  State<AdUnitWidget> createState() => _AdUnitWidgetWebState();
}

class _AdUnitWidgetWebState extends State<AdUnitWidget>
    with AutomaticKeepAliveClientMixin {
  static int adUnitCounter = 0;

  // Make the ad as wide as the available space, so Adsense delivers the best
  // possible size.
  Size adSize = const Size(double.infinity, 1);

  // Size adSize = const Size(600, 1); // It seems ads don't resize, do we need to define fixed sizes for ad units?
  late web.HTMLElement adUnitDiv;
  static final JSString _adStatusKey = 'adStatus'.toJS;

  @override
  bool get wantKeepAlive => true;

  static final web.ResizeObserver adSenseResizeObserver = web.ResizeObserver(
      (JSArray<web.ResizeObserverEntry> entries, web.ResizeObserver observer) {
    // only check first one
    final web.Element target = entries.toDart[0].target;
    if (target.isConnected) {
      // First time resized since attached to DOM -> attachment callback from Flutter docs by David
      onElementAttached(target as web.HTMLElement);
      observer.disconnect();
    }
  }.toJS);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SizedBox.fromSize(
      size: adSize,
      child: HtmlElementView.fromTagName(
          tagName: 'div', onElementCreated: onElementCreated),
    );
  }

  void onElementCreated(Object element) {
    // Adding ins inside of the adUnit
    adUnitDiv = element as web.HTMLElement
      ..id = 'adUnit${adUnitCounter++}'
      ..append(widget._insElement);

    if (kDebugMode) {
      debugPrint(
          'onElementCreated: $adUnitDiv with style height=${element.offsetHeight} and width=${element.offsetWidth}');
    }

    // Using Resize observer to detect element attached to DOM
    adSenseResizeObserver.observe(adUnitDiv);

    // Using Mutation Observer to detect when adslot is being loaded based on https://support.google.com/adsense/answer/10762946?hl=en
    web.MutationObserver(
            (JSArray<JSObject> entries, web.MutationObserver observer) {
      for (final JSObject entry in entries.toDart) {
        final web.HTMLElement target =
            (entry as web.MutationRecord).target as web.HTMLElement;
        if (kDebugMode) {
          debugPrint('MO current entry: $target');
        }
        if (isLoaded(target)) {
          // observer.disconnect();
          if (isFilled(target)) {
            updateWidgetSize(Size(
              target.offsetWidth.toDouble(),
              target.offsetHeight.toDouble(),
            ));
          } else {
            // Prevent scrolling issues over empty ad slot
            target.style.pointerEvents = 'none';
            target.style.height = '0px';
            updateWidgetSize(Size.zero);
          }
        }
      }
    }.toJS)
        .observe(
            widget._insElement,
            web.MutationObserverInit(
                attributes: true,
                attributeFilter: <JSString>['data-ad-status'.toJS].toJS));
  }

  static void onElementAttached(web.HTMLElement element) {
    if (kDebugMode) {
      debugPrint(
          'Element ${element.id} attached with style: height=${element.offsetHeight} and width=${element.offsetWidth}');
    }
    adsbygoogle.requestAd();
  }

  bool isLoaded(web.HTMLElement target) {
    final bool isLoaded =
        target.dataset.getProperty(_adStatusKey).isDefinedAndNotNull;
    if (kDebugMode) {
      if (isLoaded) {
        debugPrint('Ad is loaded');
      } else {
        debugPrint('Ad is loading');
      }
    }
    return isLoaded;
  }

  bool isFilled(web.HTMLElement target) {
    final JSAny? adStatus = target.dataset.getProperty(_adStatusKey);
    switch (adStatus) {
      case AdStatus.FILLED:
        {
          if (kDebugMode) {
            debugPrint('Ad filled');
          }
          return true;
        }
      case AdStatus.UNFILLED:
        {
          if (kDebugMode) {
            debugPrint('Ad unfilled!');
          }
          return false;
        }
      default:
        if (kDebugMode) {
          // Printing warning as this scenario is unexpected
          web.console.warn('No data-ad-status attribute found'.toJS);
        }
        return false;
    }
  }

  void updateWidgetSize(Size newSize) {
    if (kDebugMode) {
      debugPrint('Resizing AdUnit to $newSize');
    }
    setState(() {
      adSize = newSize;
    });
  }
}

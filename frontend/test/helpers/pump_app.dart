import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:material_ui/material_ui.dart';

extension PumpApp on WidgetTester {
  /// Pumps [child] inside a themed app (light by default).
  Future<void> pumpApp(Widget child, {bool dark = false}) => pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  /// Pumps a full-screen [page] on a phone-sized view, with its providers
  /// read from [container].
  Future<void> pumpPage(
    Widget page, {
    required ProviderContainer container,
    Size size = const Size(390, 844),
  }) async {
    view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(view.reset);
    await pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light(), home: page),
      ),
    );
  }

  /// Taps [pin] on a `PinPad`, one key at a time.
  Future<void> enterPin(String pin) async {
    for (final digit in pin.split('')) {
      await tap(find.text(digit).last);
      await pump();
    }
  }
}

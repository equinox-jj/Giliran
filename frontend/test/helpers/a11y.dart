import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The smallest phone the layouts support (DESIGN_SYSTEM §10, 360 dp).
const a11yPhone = Size(360, 800);

/// Sets the system text scale to 130% for the rest of the test.
void useLargeText(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Asserts the screen on [tester] laid out without overflow and meets the
/// Android tap target, labeled tap target and text contrast guidelines.
/// Call `tester.ensureSemantics()` before pumping.
Future<void> expectAccessibleScreen(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

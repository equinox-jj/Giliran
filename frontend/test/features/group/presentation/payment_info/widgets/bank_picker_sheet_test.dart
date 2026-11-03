import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/constants/banks.dart';
import 'package:giliran/features/group/presentation/payment_info/widgets/bank_picker_sheet.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/pump_app.dart';

void main() {
  // The list sits in a non-scrolling sheet body; an unbounded height there
  // left only the scrim on screen.
  testWidgets('opens in a tall sheet without layout errors', (tester) async {
    // Arrange
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppSheet<String>(context, tall: true, builder: (_) => const BankPickerSheet()),
          child: const Text('open'),
        ),
      ),
    );

    // Act
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Assert
    expect(tester.takeException(), isNull);
    expect(find.byType(BankPickerSheet), findsOneWidget);
    expect(find.text(Banks.all.first), findsOneWidget);
  });
}

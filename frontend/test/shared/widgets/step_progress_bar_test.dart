import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('shows the step label', (tester) async {
    // Act
    await tester.pumpApp(const SizedBox(width: 320, child: StepProgressBar(step: 1, total: 2)));

    // Assert
    expect(find.text('1 dari 2'), findsOneWidget);
  });

  testWidgets('draws one segment per step', (tester) async {
    // Act
    await tester.pumpApp(const SizedBox(width: 320, child: StepProgressBar(step: 2, total: 3)));

    // Assert
    expect(
      find.descendant(of: find.byType(StepProgressBar), matching: find.byType(AnimatedContainer)),
      findsNWidgets(3),
    );
  });
}

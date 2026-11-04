import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('ReorderableMemberRow reads its position, name and slot', (tester) async {
    // Arrange
    final handle = tester.ensureSemantics();

    // Act
    await tester.pumpApp(
      const SizedBox(width: 360, child: ReorderableMemberRow(position: 3, name: 'Bu Rina', slotNo: 7)),
    );

    // Assert
    expect(find.bySemanticsLabel('Urutan 3: Bu Rina, slot 07'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a locked ReorderableMemberRow has no drag handle', (tester) async {
    // Act
    await tester.pumpApp(
      const SizedBox(width: 360, child: ReorderableMemberRow(position: 1, name: 'Bu Rina', slotNo: 7, locked: true)),
    );

    // Assert
    expect(find.byType(AppIcon), findsNothing);
  });

  testWidgets('ReadinessChecklist shows the fix action only on missing rows', (tester) async {
    // Arrange
    var tapped = 0;
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: ReadinessChecklist(
          rows: [
            const ReadinessRow(title: 'Semua slot terisi', done: true, actionLabel: 'Undang'),
            ReadinessRow(
              title: 'Info rekening ada',
              done: false,
              actionLabel: 'Isi rekening',
              onAction: () => tapped++,
            ),
          ],
        ),
      ),
    );

    // Act
    await tester.tap(find.text('Isi rekening'));

    // Assert
    expect(find.text('Undang'), findsNothing);
    expect(tapped, 1);
  });
}

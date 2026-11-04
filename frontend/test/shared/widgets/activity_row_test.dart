import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/constants/app_icons.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('shows the sentence, the time and a struck-through diff', (tester) async {
    // Act
    await tester.pumpApp(
      const ActivityRow(
        icon: AppIcons.pencilSimple,
        title: 'Bu Rina mengubah iuran',
        time: '19.30',
        diffs: [ActivityRowDiff(label: 'iuran', before: 'Rp150.000', after: 'Rp200.000')],
      ),
    );

    // Assert
    expect(find.text('Bu Rina mengubah iuran'), findsOneWidget);
    expect(find.text('19.30'), findsOneWidget);
    final diff = tester.widget<RichText>(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('→')),
    );
    expect(diff.text.toPlainText(), 'iuran Rp150.000 → Rp200.000');
    TextSpan? struck;
    diff.text.visitChildren((span) {
      if (span is TextSpan && span.text == 'Rp150.000') struck = span;
      return true;
    });
    expect(struck?.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('reads as one sentence with its time and diff', (tester) async {
    // Arrange
    final handle = tester.ensureSemantics();

    // Act
    await tester.pumpApp(
      const ActivityRow(
        icon: AppIcons.pencilSimple,
        title: 'Bu Rina mengubah iuran',
        time: '19.30',
        diffs: [ActivityRowDiff(label: 'iuran', before: 'Rp150.000', after: 'Rp200.000')],
      ),
    );

    // Assert
    expect(find.bySemanticsLabel('Bu Rina mengubah iuran, 19.30. iuran dari Rp150.000 jadi Rp200.000'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a system row fills its circle with ink, others with bg.subtle', (tester) async {
    // Act
    await tester.pumpApp(
      const Column(
        children: [
          ActivityRow(key: Key('system'), icon: AppIcons.flag, title: 'Arisan dimulai', time: '08.00', system: true),
          ActivityRow(key: Key('actor'), icon: AppIcons.plus, title: 'Bu Rina membuat grup', time: '08.00'),
        ],
      ),
    );

    // Assert
    final colors = tester.element(find.byKey(const Key('system'))).colors;
    Color? circleOf(String key) =>
        (tester
                    .widget<Container>(
                      find.descendant(of: find.byKey(Key(key)), matching: find.byType(Container)).first,
                    )
                    .decoration!
                as ShapeDecoration)
            .color;
    expect(circleOf('system'), colors.ink);
    expect(circleOf('actor'), colors.subtle);
  });
}

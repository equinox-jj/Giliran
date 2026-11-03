import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/constants/app_icons.dart';
import 'package:giliran/shared/widgets/widgets.dart';

import '../../helpers/pump_app.dart';

Finder _icon(String asset) => find.byWidgetPredicate((w) => w is AppIcon && w.asset == asset);

void main() {
  testWidgets('reads its semantics label instead of the numbers', (tester) async {
    // Arrange
    const label = '8 dari 10 anggota sudah bayar, 1 menunggu dicek';
    final handle = tester.ensureSemantics();

    // Act
    await tester.pumpApp(
      const GiliranRing(value: 8, total: 10, pending: 1, size: GiliranRingSize.s96, semanticsLabel: label),
    );
    await tester.pumpAndSettle();

    // Assert
    expect(find.bySemanticsLabel(label), findsOneWidget);
    handle.dispose();
  });

  testWidgets('shows the count while not complete', (tester) async {
    // Act
    await tester.pumpApp(
      const GiliranRing(value: 3, total: 10, size: GiliranRingSize.s48, semanticsLabel: 'x'),
    );
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('3/10'), findsOneWidget);
    expect(_icon(AppIcons.checkBold), findsNothing);
  });

  testWidgets('a complete ring shows a check icon', (tester) async {
    // Act
    await tester.pumpApp(
      const GiliranRing(value: 10, total: 10, size: GiliranRingSize.s96, semanticsLabel: 'x'),
    );
    await tester.pumpAndSettle();

    // Assert
    expect(_icon(AppIcons.checkBold), findsOneWidget);
  });
}

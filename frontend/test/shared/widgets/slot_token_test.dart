import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/shared/widgets/widgets.dart';

import '../../helpers/pump_app.dart';

void main() {
  final cases = <String, SlotToken>{
    'Periode 2, diterima Rina': const SlotToken(periodNo: 2, state: SlotTokenState.done, winnerName: 'Rina'),
    'Periode 4, sedang berjalan': const SlotToken(periodNo: 4, state: SlotTokenState.current),
    'Periode 6, belum mulai': const SlotToken(periodNo: 6, state: SlotTokenState.upcoming),
    'Periode 3, kamu menang': const SlotToken(periodNo: 3, state: SlotTokenState.done, winnerName: 'Kamu', iWon: true),
  };
  for (final MapEntry(key: label, value: token) in cases.entries) {
    testWidgets('reads "$label"', (tester) async {
      // Arrange
      final handle = tester.ensureSemantics();

      // Act
      await tester.pumpApp(token);

      // Assert
      expect(find.bySemanticsLabel(label), findsOneWidget);
      handle.dispose();
    });
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('Salin copies the digits only', (tester) async {
    // Arrange
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpApp(
      const SizedBox(
        width: 360,
        child: BankAccountCard(
          info: PaymentInfo(bankName: 'BCA', accountNumber: '1234567890', accountHolder: 'Rina Ayu'),
        ),
      ),
    );

    // Act
    await tester.tap(find.text('Salin'));
    await tester.pump();

    // Assert
    expect(copied, '1234567890');
    expect(find.text('1234 5678 90'), findsOneWidget);
    expect(find.text('a.n. Rina Ayu'), findsOneWidget);
  });

  testWidgets('a member sees a note when no account is set', (tester) async {
    // Act
    await tester.pumpApp(const SizedBox(width: 360, child: BankAccountCard(info: PaymentInfo())));

    // Assert
    expect(find.text('Pengurus belum menambahkan rekening.'), findsOneWidget);
  });

  testWidgets('the organizer can add a missing account', (tester) async {
    // Arrange
    var adds = 0;
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: BankAccountCard(info: const PaymentInfo(), onAdd: () => adds++),
      ),
    );

    // Act
    await tester.tap(find.text('Tambahkan rekening'));

    // Assert
    expect(adds, 1);
  });
}

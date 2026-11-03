import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('without a QRIS the organizer gets the upload tile', (tester) async {
    // Arrange
    var uploads = 0;
    await tester.pumpApp(SizedBox(width: 360, child: QrisCard(onUpload: () => uploads++)));

    // Act
    await tester.tap(find.text('Upload QRIS'));

    // Assert
    expect(uploads, 1);
  });

  testWidgets('a saved QRIS shows the merchant and the checked caption', (tester) async {
    // Act
    await tester.pumpApp(const SizedBox(width: 360, child: QrisCard(hasQris: true, merchantName: 'RINA AYU')));

    // Assert
    expect(find.text('RINA AYU'), findsOneWidget);
    expect(find.text('Disimpan & dicek'), findsOneWidget);
  });

  testWidgets('shows the validation error inline', (tester) async {
    // Act
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: QrisCard(onUpload: () {}, errorText: 'QRIS rusak'),
      ),
    );

    // Assert
    expect(find.text('QRIS rusak'), findsOneWidget);
  });
}

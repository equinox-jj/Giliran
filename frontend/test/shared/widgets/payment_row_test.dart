import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/constants/app_icons.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('reads as one sentence with slot, name, status and detail', (tester) async {
    // Arrange
    final semantics = tester.ensureSemantics();

    // Act
    await tester.pumpApp(
      PaymentRow(
        slotNo: 7,
        name: 'Pak Dedi',
        status: ChipStatus.pendingReview,
        subtitle: 'Upload Kemarin',
        onTap: () {},
      ),
    );

    // Assert
    expect(find.bySemanticsLabel('Slot 07, Pak Dedi, Menunggu cek. Upload Kemarin'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('my unpaid row shows the upload circle', (tester) async {
    // Arrange
    var uploads = 0;

    // Act
    await tester.pumpApp(
      PaymentRow(
        slotNo: 3,
        name: 'Kamu',
        status: ChipStatus.unpaid,
        subtitle: 'Jatuh tempo Sab, 25 Okt',
        mine: true,
        onUpload: () => uploads++,
      ),
    );
    await tester.tap(find.byType(CircleIconButton));

    // Assert
    expect(find.bySemanticsLabel('Upload bukti'), findsOneWidget);
    expect(uploads, 1);
  });

  testWidgets('a pending row gives managers the review chevron', (tester) async {
    // Arrange
    var reviews = 0;
    await tester.pumpApp(
      PaymentRow(
        slotNo: 7,
        name: 'Pak Dedi',
        status: ChipStatus.pendingReview,
        subtitle: 'Upload Kemarin',
        onReview: () => reviews++,
      ),
    );

    // Act
    await tester.tap(find.byType(CircleIconButton));

    // Assert
    expect(find.bySemanticsLabel('Cek bukti Pak Dedi'), findsOneWidget);
    expect(reviews, 1);
  });

  testWidgets('a guest row says Tamu and a pending sync shows the dot', (tester) async {
    // Act
    await tester.pumpApp(
      const PaymentRow(
        slotNo: 8,
        name: 'Bu Sri',
        status: ChipStatus.paid,
        subtitle: 'Dibayar Kemarin · Tunai',
        guest: true,
        pendingSync: true,
      ),
    );

    // Assert
    expect(find.text('TAMU'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-row-sync-dot')), findsOneWidget);
    expect(find.byType(DashedBorder), findsOneWidget);
  });

  testWidgets('fits a 360 dp phone with the overflow menu and a long status', (tester) async {
    // Arrange
    tester.view
      ..physicalSize = const Size(360, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Act
    await tester.pumpApp(
      SizedBox(
        width: 328,
        child: PaymentRow(
          slotNo: 8,
          name: 'Ibu Sri Rahayu Wulandari',
          status: ChipStatus.overdue,
          subtitle: 'Jatuh tempo Sab, 18 Okt',
          subtitleAlert: true,
          menuItems: [OverflowMenuItem(label: 'Tandai sudah bayar', icon: AppIcons.handCoins, onSelected: () {})],
        ),
      ),
    );

    // Assert
    expect(tester.takeException(), isNull);
  });
}

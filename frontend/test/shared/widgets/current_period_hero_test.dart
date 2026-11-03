import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('shows the amount, caption and action', (tester) async {
    // Arrange
    var taps = 0;
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: CurrentPeriodHero(
          title: 'Arisan RT 05',
          subtitle: 'Periode 4 dari 10',
          ringValue: 8,
          ringTotal: 10,
          ringSemantics: '8 dari 10 anggota sudah bayar',
          amount: 1600000,
          amountCaption: 'dari Rp2.000.000',
          action: CurrentPeriodHeroAction(label: 'Upload bukti', onPressed: () => taps++),
        ),
      ),
    );

    // Act
    await tester.tap(find.text('Upload bukti'));

    // Assert
    expect(find.text('dari Rp2.000.000'), findsOneWidget);
    expect(find.text('Periode 4 dari 10'), findsOneWidget);
    expect(taps, 1);
  });

  testWidgets('a note replaces the button', (tester) async {
    // Act
    await tester.pumpApp(
      const SizedBox(
        width: 360,
        child: CurrentPeriodHero(
          title: 'Arisan RT 05',
          subtitle: 'Periode 4 dari 10',
          ringValue: 10,
          ringTotal: 10,
          ringSemantics: '10 dari 10 anggota sudah bayar',
          note: 'Tinggal tunggu kocokan',
        ),
      ),
    );

    // Assert
    expect(find.text('Tinggal tunggu kocokan'), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
  });
}

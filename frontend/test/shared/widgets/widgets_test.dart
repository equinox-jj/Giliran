import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/app/component_gallery_page.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('AppButton', () {
    testWidgets('shows the disabled reason and ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        AppButton(
          label: 'Mulai arisan',
          onPressed: () => taps++,
          disabledReason: 'Lengkapi info rekening dulu',
        ),
      );
      expect(find.text('Lengkapi info rekening dulu'), findsOneWidget);
      await tester.tap(find.text('Mulai arisan'));
      expect(taps, 0);
    });

    testWidgets('fires onPressed and keeps its width while loading', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpApp(AppButton(label: 'Simpan', onPressed: () => taps++));
      final idle = tester.getSize(find.byType(AppButton));
      await tester.tap(find.text('Simpan'));
      expect(taps, 1);

      await tester.pumpApp(
        AppButton(label: 'Simpan', loading: true, onPressed: () => taps++),
      );
      expect(tester.getSize(find.byType(AppButton)), idle);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(taps, 1);
    });

    testWidgets('has a 48 px hit area even when 44 high', (tester) async {
      await tester.pumpApp(AppButton.ghost(label: 'Batal', onPressed: () {}));
      expect(tester.getSize(find.byType(Pressable)).height, AppSizes.tapMin);
    });
  });

  testWidgets('StatusChip shows the fixed label for every status', (
    tester,
  ) async {
    await tester.pumpApp(
      Wrap(children: [for (final s in ChipStatus.values) StatusChip(s)]),
    );
    for (final s in ChipStatus.values) {
      expect(find.text(s.label), findsOneWidget);
    }
    expect(find.byType(TikarHatch), findsOneWidget);
  });

  testWidgets('OtpInput completes on a pasted 6-digit code', (tester) async {
    String? code;
    await tester.pumpApp(OtpInput(onCompleted: (v) => code = v));
    await tester.enterText(find.byType(TextField), '482913');
    await tester.pump();
    expect(code, '482913');
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('PinPad completes after six digits and supports delete', (
    tester,
  ) async {
    final controller = PinPadController();
    String? pin;
    await tester.pumpApp(
      SingleChildScrollView(
        child: PinPad(controller: controller, onCompleted: (v) => pin = v),
      ),
    );
    await tester.tap(find.bySemanticsLabel('1'));
    await tester.tap(find.bySemanticsLabel('9'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Hapus'));
    await tester.pump();
    expect(controller.value, '1');
    for (final d in ['2', '3', '4', '5', '6']) {
      await tester.tap(find.bySemanticsLabel(d));
    }
    expect(pin, '123456');
    controller.dispose();
  });

  testWidgets('AppStepper clamps and disables at the limit', (tester) async {
    var value = 49;
    await tester.pumpApp(
      StatefulBuilder(
        builder: (context, setState) => SizedBox(
          width: 360,
          child: AppStepper(
            label: 'Jumlah slot',
            value: value,
            min: 2,
            max: 50,
            unit: 'slot',
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Tambah'));
    await tester.pump();
    expect(value, 50);
    expect(find.text('Maksimal 50 slot'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Tambah'));
    await tester.pump();
    expect(value, 50);
  });

  testWidgets('CheckRow toggles from anywhere on the row', (tester) async {
    var checked = false;
    await tester.pumpApp(
      StatefulBuilder(
        builder: (context, setState) => SizedBox(
          width: 360,
          child: CheckRow(
            label: 'Saya sudah transfer',
            value: checked,
            onChanged: (v) => setState(() => checked = v),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Saya sudah transfer'));
    await tester.pump();
    expect(checked, isTrue);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'gallery meets tap-target and contrast guidelines '
      '(${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(390, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: const ComponentGalleryPage(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );
  }
}

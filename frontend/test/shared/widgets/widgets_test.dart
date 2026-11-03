import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/app/component_gallery_page.dart';
import 'package:giliran/core/constants/app_icons.dart';
import 'package:giliran/core/l10n/l10n.dart';
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

  testWidgets('OtpInput shrinks its boxes to fit a narrow width', (
    tester,
  ) async {
    // Arrange
    final widget = Center(
      child: SizedBox(
        width: 260,
        child: OtpInput(onCompleted: (_) {}),
      ),
    );

    // Act
    await tester.pumpApp(widget);

    // Assert
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(OtpInput)).width, lessThanOrEqualTo(260));
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

  testWidgets('PinPad shows a spinner and ignores keys while checking', (
    tester,
  ) async {
    // Arrange
    final controller = PinPadController()..value = '12';
    await tester.pumpApp(
      SingleChildScrollView(
        child: PinPad(controller: controller, checking: true, onCompleted: (_) {}),
      ),
    );

    // Act
    await tester.tap(find.bySemanticsLabel('3'), warnIfMissed: false);
    await tester.pump();

    // Assert
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(controller.value, '12');
    controller.dispose();
  });

  group('PinPad.keySizeFor', () {
    test('is the design size on a typical phone', () {
      // Arrange
      const size = Size(390, 844);

      // Act
      final key = PinPad.keySizeFor(size, margin: 20);

      // Assert
      expect(key, closeTo(AppSizes.pinKey, 0.01));
    });

    test('shrinks on a short phone', () {
      // Arrange
      const size = Size(375, 667);

      // Act
      final key = PinPad.keySizeFor(size, margin: 20);

      // Assert
      expect(key, lessThan(AppSizes.pinKey));
      expect(key, greaterThanOrEqualTo(AppSizes.pinKeyMin));
    });

    test('is limited by width on a narrow phone', () {
      // Arrange
      const size = Size(300, 900);

      // Act
      final key = PinPad.keySizeFor(size, margin: 20);

      // Assert
      expect(key, lessThan(AppSizes.pinKey));
    });

    test('grows on a tablet but stops at the max', () {
      // Arrange
      const size = Size(820, 1180);

      // Act
      final key = PinPad.keySizeFor(size, margin: 32);

      // Assert
      expect(key, AppSizes.pinKeyMax);
    });

    test('never drops below the min', () {
      // Arrange
      const size = Size(320, 480);

      // Act
      final key = PinPad.keySizeFor(size, margin: 20);

      // Assert
      expect(key, AppSizes.pinKeyMin);
    });
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

  group('AppStepper typing', () {
    Future<List<int>> pumpStepper(WidgetTester tester) async {
      final changes = <int>[];
      var value = 10;
      await tester.pumpApp(
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 360,
            child: AppStepper(
              label: 'Jumlah slot',
              value: value,
              min: 2,
              max: 50,
              helper: '$value periode',
              onChanged: (v) => setState(() {
                value = v;
                changes.add(v);
              }),
            ),
          ),
        ),
      );
      return changes;
    }

    testWidgets('replaces the current value instead of splicing into it', (
      tester,
    ) async {
      // Arrange
      final changes = await pumpStepper(tester);

      // Act
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();

      // Assert
      expect(find.text('12'), findsOneWidget);
      expect(find.text('12 periode'), findsOneWidget);
      expect(changes.last, 12);
    });

    testWidgets('selects the whole value on focus', (tester) async {
      // Arrange
      await pumpStepper(tester);

      // Act
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Assert
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );
    });

    testWidgets('caps input at the digits of max and clamps on submit', (
      tester,
    ) async {
      // Arrange
      final changes = await pumpStepper(tester);
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Act
      await tester.enterText(find.byType(TextField), '120');
      await tester.pump();
      final typed = tester.widget<TextField>(find.byType(TextField)).controller!.text;
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Assert
      expect(typed, '12');
      expect(changes.last, 12);
    });
  });

  group('SettingsRow', () {
    testWidgets('gives the label the row and pins the caret to the end', (
      tester,
    ) async {
      // Arrange
      const rowWidth = 358.0;
      await tester.pumpApp(
        SizedBox(
          width: rowWidth,
          child: SettingsRow.navigation(
            icon: AppIcons.shieldCheck,
            label: 'Keamanan',
            onTap: () {},
          ),
        ),
      );

      // Act
      final rowRect = tester.getRect(find.byType(SettingsRow));
      final labelSize = tester.getSize(find.text('Keamanan'));
      final caretRect = tester.getRect(find.byType(AppIcon).last);

      // Assert
      expect(labelSize.height, lessThan(30), reason: 'label must stay on one line');
      expect(caretRect.right, closeTo(rowRect.right - AppSpace.s4, 0.5));
    });

    testWidgets('caps a long value so the label keeps most of the row', (
      tester,
    ) async {
      // Arrange
      const rowWidth = 358.0;
      await tester.pumpApp(
        const SizedBox(
          width: rowWidth,
          child: SettingsRow.info(
            label: 'Versi app',
            value: '1.0.0 (1) a very long build string that would overflow',
          ),
        ),
      );

      // Act
      final valueWidth = tester.getSize(find.textContaining('1.0.0')).width;

      // Assert
      expect(valueWidth, lessThanOrEqualTo((rowWidth - 2 * AppSpace.s4) * 0.45));
      expect(tester.takeException(), isNull);
    });
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

  group('PageDots', () {
    testWidgets('stretches the current dot and reads its position', (
      tester,
    ) async {
      // Arrange & Act
      await tester.pumpApp(const PageDots(count: 3, index: 1));

      // Assert
      final widths = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((d) => d.constraints?.maxWidth)
          .toList();
      expect(widths, [8, 24, 8]);
      expect(find.bySemanticsLabel('Halaman 2 dari 3'), findsOneWidget);
    });
  });

  testWidgets('AppButton draws the trailing icon after the label', (
    tester,
  ) async {
    // Arrange & Act
    await tester.pumpApp(
      AppButton(
        label: 'Lanjut',
        trailingIcon: AppIcons.arrowRight,
        onPressed: () {},
      ),
    );

    // Assert
    final label = tester.getCenter(find.text('Lanjut'));
    final icon = tester.getCenter(find.byType(AppIcon));
    expect(icon.dx, greaterThan(label.dx));
  });

  group('AvatarPicker', () {
    testWidgets('empty: asks for an optional photo and opens on tap', (
      tester,
    ) async {
      // Arrange
      var taps = 0;
      await tester.pumpApp(AvatarPicker(onTap: () => taps++));

      // Act
      await tester.tap(find.bySemanticsLabel('Tambah foto profil'));

      // Assert
      expect(find.text('Foto profil (opsional)'), findsOneWidget);
      expect(taps, 1);
    });

    testWidgets('uploading: shows the percentage and ignores taps', (
      tester,
    ) async {
      // Arrange
      var taps = 0;
      await tester.pumpApp(AvatarPicker(progress: 0.42, onTap: () => taps++));

      // Act
      await tester.tap(find.byType(AvatarPicker));

      // Assert
      expect(find.text('Mengunggah… 42%'), findsOneWidget);
      expect(taps, 0);
    });

    testWidgets('failed: shows the reason and Coba lagi retries', (
      tester,
    ) async {
      // Arrange
      var retries = 0;
      await tester.pumpApp(
        AvatarPicker(
          errorText: 'Foto lebih dari 5 MB.',
          onTap: () {},
          onRetry: () => retries++,
        ),
      );

      // Act
      await tester.tap(find.text('Coba lagi'));

      // Assert
      expect(find.text('Foto lebih dari 5 MB.'), findsOneWidget);
      expect(retries, 1);
    });

    testWidgets('the sheet offers Hapus foto only when there is a photo', (
      tester,
    ) async {
      // Arrange
      AvatarSheetAction? picked;
      await tester.pumpApp(
        Builder(
          builder: (context) => AppButton(
            label: 'Buka',
            onPressed: () async => picked = await showAvatarSourceSheet(context, canRemove: true),
          ),
        ),
      );
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      final offersRemove = find.text('Hapus foto').evaluate().isNotEmpty;

      // Act
      await tester.tap(find.text('Kamera'));
      await tester.pumpAndSettle();

      // Assert
      expect(offersRemove, isTrue);
      expect(picked, AvatarSheetAction.camera);
    });
  });

  group('IllustrationColorMapper', () {
    test('keeps light colors and maps them for dark', () {
      // Arrange
      const light = IllustrationColorMapper(GiliranColors.light);
      const dark = IllustrationColorMapper(GiliranColors.dark);

      // Act
      Color map(IllustrationColorMapper m, Color c) => m.substitute(null, 'path', 'stroke', c);

      // Assert
      expect(map(light, AppPalette.kopi900), AppPalette.kopi900);
      expect(map(dark, AppPalette.kopi900), GiliranColors.dark.textPrimary);
      expect(map(dark, AppPalette.kopi50), GiliranColors.dark.page);
      expect(
        map(dark, AppPalette.jambu200),
        GiliranColors.dark.tones[2].surface,
      );
      expect(map(dark, AppPalette.bata600), AppPalette.bata600);
    });
  });

  for (final dark in [false, true]) {
    testWidgets(
      'gallery meets tap-target and contrast guidelines '
      '(${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(390, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // The gallery picks its theme from the platform brightness.
        tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            locale: const Locale('id'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ComponentGalleryPage(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        // Grow the view to the whole gallery, so no section sits cut off at
        // the bottom edge under the floating nav bar.
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
        tester.view.physicalSize = Size(390, 6000 + scroll.maxScrollExtent);
        await tester.pump(const Duration(milliseconds: 500));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );
  }
}

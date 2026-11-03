import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/l10n/l10n.dart';
import 'package:giliran/core/l10n/locale_controller.dart';
import 'package:giliran/core/storage/preferences.dart';
import 'package:giliran/core/themes/theme_mode_controller.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:giliran/features/settings/domain/entities/user_settings.dart';
import 'package:giliran/features/settings/presentation/settings/page/settings_page.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/fake_preferences.dart';
import '../../../../../helpers/fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository repository;
  late FakePreferences prefs;
  late ProviderContainer container;
  late int deleteTaps;

  setUp(() {
    repository = FakeSettingsRepository();
    prefs = FakePreferences();
    container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repository),
        preferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    deleteTaps = 0;
  });

  /// Pumps Settings in an app whose locale and theme follow the stored
  /// controllers, like `GiliranApp`.
  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ref.watch(themeModeControllerProvider).value ?? ThemeMode.system,
            locale: ref.watch(localeControllerProvider).value ?? const Locale('id'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(onDeleteAccount: () => deleteTaps++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchOf(WidgetTester tester, String label) => tester
      .widget<Switch>(
        find.descendant(
          of: find.ancestor(of: find.text(label), matching: find.byType(GestureDetector)).first,
          matching: find.byType(Switch),
        ),
      )
      .value;

  testWidgets('toggling a switch sends only that field', (tester) async {
    // Arrange
    await pumpSettings(tester);

    // Act
    await tester.tap(find.text('Aktivitas grup'));
    await tester.pumpAndSettle();

    // Assert
    expect(repository.patches, [const UserSettingsPatch(notifyGroupActivity: true)]);
    expect(switchOf(tester, 'Aktivitas grup'), isTrue);
  });

  testWidgets('a failed save reverts the switch and shows a toast', (tester) async {
    // Arrange
    repository.updateResult = const Left(Failure.network());
    await pumpSettings(tester);

    // Act
    await tester.tap(find.text('Pengingat bayar'));
    await tester.pumpAndSettle();

    // Assert
    expect(switchOf(tester, 'Pengingat bayar'), isTrue);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('choosing English switches the app language without a restart', (tester) async {
    // Arrange
    await pumpSettings(tester);

    // Act
    await tester.tap(find.text('Bahasa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Assert
    expect(Localizations.localeOf(tester.element(find.byType(SettingsPage))), const Locale('en'));
    expect(find.text('Settings'), findsOneWidget);
    expect(repository.patches, [const UserSettingsPatch(language: 'en')]);
  });

  testWidgets('a theme choice updates the theme mode', (tester) async {
    // Arrange
    await pumpSettings(tester);

    // Act
    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();

    // Assert
    expect(container.read(themeModeControllerProvider).value, ThemeMode.dark);
    expect(prefs.themeMode, 'dark');
  });

  testWidgets('Hapus cache gambar clears the cache and confirms', (tester) async {
    // Arrange
    await pumpSettings(tester);

    // Act
    await tester.tap(find.text('Hapus cache gambar'));
    await tester.pumpAndSettle();

    // Assert
    expect(repository.clearCalls, 1);
    expect(find.text('Cache gambar dihapus.'), findsOneWidget);
  });

  testWidgets('Hapus akun opens Delete account', (tester) async {
    // Arrange
    await pumpSettings(tester);

    // Act
    await tester.tap(find.text('Hapus akun'));

    // Assert
    expect(deleteTaps, 1);
  });

  testWidgets('a failed load offers Coba lagi', (tester) async {
    // Arrange
    repository.settingsResult = const Left(Failure.network());
    await pumpSettings(tester);
    repository.settingsResult = const Right(UserSettings(notifyDrawResults: true));

    // Act
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Hasil kocokan'), findsOneWidget);
  });
}

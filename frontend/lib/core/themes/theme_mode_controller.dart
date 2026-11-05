import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/preferences.dart';

part 'theme_mode_controller.g.dart';

/// The theme choice (Ikuti sistem / Terang / Gelap), stored in
/// [Preferences] and read by `GiliranApp` for `MaterialApp.themeMode`.
@Riverpod(keepAlive: true)
class ThemeModeController() extends _$ThemeModeController {
  @override
  Future<ThemeMode> build() async {
    final value = await ref.read(preferencesProvider).readThemeMode();

    return ThemeMode.values.firstWhere((m) => m.name == value, orElse: () => ThemeMode.system);
  }

  Future<void> set(ThemeMode mode) async {
    state = AsyncData(mode);
    await ref.read(preferencesProvider).saveThemeMode(mode.name);
  }
}

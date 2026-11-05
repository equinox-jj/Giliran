import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/preferences.dart';

part 'locale_controller.g.dart';

/// The app language, `id` (default) or `en`, stored in [Preferences].
///
/// `GiliranApp` reads it for `MaterialApp.locale`; the language setting
/// calls [set], which applies without a restart.
@Riverpod(keepAlive: true)
class LocaleController() extends _$LocaleController {
  static const supported = [Locale('id'), Locale('en')];

  @override
  Future<Locale> build() async {
    final code = await ref.read(preferencesProvider).readLanguage();

    return supported.firstWhere((l) => l.languageCode == code, orElse: () => supported.first);
  }

  Future<void> set(Locale locale) async {
    state = AsyncData(locale);
    await ref.read(preferencesProvider).saveLanguage(locale.languageCode);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/l10n.dart';
import '../core/l10n/locale_controller.dart';
import '../core/themes/theme_mode_controller.dart';
import '../core/themes/themes.dart';
import '../features/auth/presentation/shared/widgets/app_lock_gate.dart';
import 'router.dart';

/// Root widget of the app.
///
/// Applies the light and dark [AppTheme], the stored theme mode and language,
/// and navigates through the app router, which also receives app links
/// (Flutter deep linking). Until the stored settings load, it shows
/// Indonesian and follows the system theme.
class const GiliranApp({super.key}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider.select((s) => s.value));
    final themeMode = ref.watch(themeModeControllerProvider.select((s) => s.value));
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode ?? ThemeMode.system,
      locale: locale ?? LocaleController.supported.first,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => AppLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

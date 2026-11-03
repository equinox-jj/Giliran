import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/themes/themes.dart';
import '../features/auth/presentation/shared/widgets/app_lock_gate.dart';
import 'router.dart';

/// Root widget of the app.
///
/// Applies the light and dark [AppTheme] and navigates through the app router.
/// [themeMode] picks which of the two themes is shown.
class const GiliranApp({
  super.key,
  final ThemeMode themeMode = ThemeMode.system,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Giliran',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => AppLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

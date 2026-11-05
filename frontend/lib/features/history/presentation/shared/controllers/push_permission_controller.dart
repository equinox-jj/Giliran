import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/services/push_service.dart';

part 'push_permission_controller.g.dart';

/// Whether the OS lets Giliran show notifications, for the S12 "Notifikasi
/// mati" banner and the S47 permission row.
@Riverpod(keepAlive: true)
class PushPermissionController() extends _$PushPermissionController {
  @override
  Future<PushPermission> build() {
    // The user can flip it in the system settings at any time, so read it
    // again whenever the app comes back to the foreground.
    final lifecycle = AppLifecycleListener(onResume: recheck);
    ref.onDispose(lifecycle.dispose);
    return ref.watch(pushServiceProvider).permission();
  }

  /// Reads the permission again (after returning from the system settings).
  Future<void> recheck() async {
    final permission = await ref.read(pushServiceProvider).permission();
    if (ref.mounted) state = AsyncData(permission);
  }

  /// Asks the OS when it hasn't been asked yet. Otherwise only the system
  /// settings can change it (turn a denied one on, a granted one off), so
  /// those open instead.
  Future<void> enable() async {
    final push = ref.read(pushServiceProvider);
    final current = state.value ?? await push.permission();
    if (current == PushPermission.notDetermined) {
      final next = await push.requestPermission();
      if (ref.mounted) state = AsyncData(next);
      return;
    }
    await push.openSettings();
  }
}

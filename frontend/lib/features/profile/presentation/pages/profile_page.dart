import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/error/failure_message.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/shared/controllers/auth_session_controller.dart';

/// Placeholder until the Profil screen is built. Has a temporary "Keluar"
/// button so the auth flow can be tested again from the start.
class const ProfilePage({super.key}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppTopBar(title: 'Profil', showBack: false),
      body: EmptyState(
        title: 'Profil',
        message: 'Pengaturan profil akan tampil di sini.',
        primaryLabel: 'Keluar',
        onPrimary: () => _logout(context, ref),
      ),
    );
  }

  /// Confirms, then signs out. The router guard sends the user to Welcome
  /// once the session is signed out.
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog(
      context,
      title: 'Keluar dari Giliran?',
      message: 'Kamu perlu masuk lagi dengan email di perangkat ini.',
      confirmLabel: 'Keluar',
    );
    if (!confirmed || !context.mounted) return;
    final failure = await ref.read(authSessionControllerProvider.notifier).logout();
    if (failure != null && context.mounted) showAppToast(context, failure.displayMessage);
  }
}

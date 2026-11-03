import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_illustrations.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/auth_status.dart';
import '../controllers/auth_session_controller.dart';

/// Wraps the whole app (`MaterialApp.router`'s `builder`) to apply S08's
/// background rules: a privacy cover over an unlocked session while the app
/// is not in the foreground, so the app switcher snapshot shows no data, and
/// the lock again after five minutes away (FR-AUTH-03).
class const AppLockGate({
  super.key,
  required final Widget child,

  /// The clock, replaced in tests.
  final DateTime Function() now = DateTime.now,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState() extends ConsumerState<AppLockGate> {
  final _covered = ValueNotifier(false);
  late final AppLifecycleListener _lifecycle;
  DateTime? _hiddenAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // iOS takes the app switcher snapshot on `inactive`, so cover then.
      onInactive: _cover,
      onHide: () => _hiddenAt ??= widget.now(),
      onResume: _onResume,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _covered.dispose();
    super.dispose();
  }

  void _cover() => _covered.value = true;

  Future<void> _onResume() async {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt != null) {
      await ref.read(authSessionControllerProvider.notifier).lockIfIdle(hiddenAt, now: widget.now());
    }
    if (mounted) _covered.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(child: _CoverLayer(covered: _covered)),
      ],
    );
  }
}

/// Shows [_PrivacyCover] while [covered] is set and the session is open. The
/// lock and sign-in screens hold nothing private, and skipping them avoids a
/// flash over S08 while the Face ID prompt has the app inactive.
class const _CoverLayer({required final ValueListenable<bool> covered}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(
      authSessionControllerProvider.select((s) => s.value is AuthUnlocked),
    );

    return ValueListenableBuilder(
      valueListenable: covered,
      builder: (context, covered, _) => covered && unlocked ? const _PrivacyCover() : const SizedBox.shrink(),
    );
  }
}

/// The page color with the splash kaleng, like the launch screen.
class const _PrivacyCover() extends StatelessWidget {
  static const kalengSize = 120.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.page,
      child: const Center(
        child: Illustration(
          AppIllustrations.splashKaleng,
          width: kalengSize,
          height: kalengSize,
        ),
      ),
    );
  }
}

import '../../../../../core/l10n/l10n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_illustrations.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../shared/controllers/biometric_controller.dart';
import '../../shared/widgets/auth_scaffold.dart';
import '../../shared/widgets/biometric_copy.dart';

class const BiometricOptInPage({super.key, required final VoidCallback onDone}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<BiometricOptInPage> createState() => _BiometricOptInPageState();
}

class _BiometricOptInPageState() extends ConsumerState<BiometricOptInPage> {
  final _saving = ValueNotifier<bool?>(null);
  bool _left = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      biometricControllerProvider,
      (_, next) {
        if (next.isLoading) return;
        if (next.hasError || next.value?.shouldOffer != true) _leave();
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _saving.dispose();
    super.dispose();
  }

  void _leave() {
    if (_left) return;
    _left = true;
    // May run while the first frame builds.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) widget.onDone();
      })
      ..ensureVisualUpdate();
  }

  Future<void> _choose(bool enabled) async {
    if (_saving.value != null) return;
    _saving.value = enabled;
    final failure = await ref.read(biometricControllerProvider.notifier).setEnabled(enabled);
    if (!mounted) return;
    if (failure != null) showAppToast(context, failure.displayMessage(context.l10n));
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    // Only whether to offer shapes the scaffold (the docked actions); the
    // biometric kind is read by [_Offer] itself.
    final offer = ref.watch(biometricControllerProvider.select((s) => s.value?.shouldOffer == true));

    return AuthScaffold(
      // No bar: the panel starts where it would end.
      showTopBar: false,
      topPadding: AppSizes.topBarH,
      bottomPadding: 28,
      body: offer ? const _Offer() : const SizedBox.shrink(),
      bottom: offer ? _Actions(saving: _saving, onChoose: _choose) : null,
    );
  }
}

/// The biometric illustration on the hero panel, the headline and the reassurance.
class const _Offer() extends ConsumerWidget {
  /// Height of the hero panel.
  static const heroH = 300.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(biometricControllerProvider.select((s) => s.value?.kind));
    if (kind == null) return const SizedBox.shrink();

    final c = context.colors;
    final t = AppTextStyles.of(context);
    final name = kind.nameOn(context.l10n, Theme.of(context).platform);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: heroH,
          alignment: Alignment.center,
          decoration: ShapeDecoration(color: c.hero, shape: AppShapes.squircle(AppRadius.xl)),
          child: const Illustration(AppIllustrations.biometricUnlock, width: 220, height: 240),
        ),
        const SizedBox(height: AppSpace.s8),
        HeadlineText(context.l10n.authBiometricOptInHeadline(name)),
        const SizedBox(height: AppSpace.s3),
        Text(
          context.l10n.authBiometricOptInCaption,
          style: t.bodyLg.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

/// "Aktifkan" and "Nanti saja". [saving] holds the choice being saved.
class const _Actions({
  required final ValueNotifier<bool?> saving,
  required final ValueChanged<bool> onChoose,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: saving,
      builder: (context, choice, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EnableButton(
            loading: choice == true,
            onPressed: choice == null ? () => onChoose(true) : null,
          ),
          const SizedBox(height: 6),
          // Ghost buttons are 44 high; this one takes the full 52 row.
          SizedBox(
            height: AppSizes.buttonH,
            child: Center(
              child: AppButton.ghost(
                label: context.l10n.laterButton,
                block: true,
                loading: choice == false,
                onPressed: choice == null ? () => onChoose(false) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Aktifkan" with the fingerprint or face icon of this device.
class const _EnableButton({
  required final bool loading,
  required final VoidCallback? onPressed,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(biometricControllerProvider.select((s) => s.value?.kind));

    return AppButton(
      label: context.l10n.authEnable,
      icon: kind?.icon,
      block: true,
      loading: loading,
      onPressed: onPressed,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../auth/presentation/shared/widgets/auth_scaffold.dart';
import '../../../../auth/presentation/shared/widgets/pin_entry.dart';
import '../controllers/delete_account_controller.dart';

/// Delete account (S48): explanation with "Saya mengerti", the PIN, then a
/// done screen that hands over to Welcome.
class const DeleteAccountPage({
  super.key,

  /// Leaves the flow from the first step.
  required final VoidCallback onClose,
  required final VoidCallback onForgotPin,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState() extends ConsumerState<DeleteAccountPage> {
  final _pin = PinPadController();

  @override
  void initState() {
    super.initState();
    ref.listenManual(deleteAccountControllerProvider, _onState);
    _pin.addListener(_onTyping);
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _onState(DeleteAccountState? previous, DeleteAccountState next) {
    // A new step, or a rejected PIN, starts the pad empty.
    if (previous?.step != next.step || (next.failure != null && next.failure != previous?.failure)) {
      _pin.clear();
    }
  }

  void _onTyping() {
    if (_pin.value.isNotEmpty) ref.read(deleteAccountControllerProvider.notifier).clearFailure();
  }

  void _back() {
    if (!ref.read(deleteAccountControllerProvider.notifier).back()) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final step = ref.watch(deleteAccountControllerProvider.select((s) => s.step));

    return PopScope(
      // After deletion there is nothing to go back to.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && step != DeleteAccountStep.done) _back();
      },
      child: switch (step) {
        DeleteAccountStep.explain => AuthScaffold(
          title: l10n.deleteAccountTitle,
          modal: true,
          onBack: widget.onClose,
          body: const _Explain(),
          bottom: const _ContinueButton(),
        ),
        DeleteAccountStep.pin => AuthScaffold(
          title: l10n.deleteAccountTitle,
          pinPad: true,
          onBack: _back,
          body: _PinStep(controller: _pin, onForgotPin: widget.onForgotPin),
        ),
        DeleteAccountStep.done => const AuthScaffold(
          showBack: false,
          centerBody: true,
          body: _Done(),
          bottom: _FinishButton(),
        ),
      },
    );
  }
}

/// Step 1: what is deleted, what stays, the blocked reason and the check.
class const _Explain() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final (:understood, :blocked) = ref.watch(
      deleteAccountControllerProvider.select((s) => (understood: s.understood, blocked: s.blocked)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeadlineText(l10n.deleteAccountHeadline),
        const SizedBox(height: AppSpace.s6),
        if (blocked) ...[
          AppBanner(message: l10n.deleteAccountBlocked, variant: AppBannerVariant.error),
          const SizedBox(height: AppSpace.s6),
        ],
        _Point(
          icon: AppIcons.trash,
          title: l10n.deleteAccountRemoved,
          body: l10n.deleteAccountRemovedBody,
          color: c.rejected.fg,
        ),
        const SizedBox(height: AppSpace.s4),
        _Point(
          icon: AppIcons.receipt,
          title: l10n.deleteAccountKept,
          body: l10n.deleteAccountKeptBody,
          color: c.textSecondary,
        ),
        const SizedBox(height: AppSpace.s6),
        CheckRow(
          label: l10n.deleteAccountUnderstand,
          value: understood,
          onChanged: blocked ? null : ref.read(deleteAccountControllerProvider.notifier).setUnderstood,
        ),
      ],
    );
  }
}

class const _Point({
  required final String icon,
  required final String title,
  required final String body,
  required final Color color,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(icon, size: AppSizes.iconLg, color: color),
        const SizedBox(width: AppSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.label.copyWith(color: c.textPrimary)),
              const SizedBox(height: AppSpace.s1),
              Text(body, style: t.body.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class const _ContinueButton() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(deleteAccountControllerProvider.select((s) => s.understood && !s.blocked));
    return AppButton(
      label: context.l10n.deleteAccountContinue,
      block: true,
      onPressed: enabled ? ref.read(deleteAccountControllerProvider.notifier).next : null,
    );
  }
}

/// Step 2: the current PIN, with the wrong-PIN and lock rules.
class const _PinStep({
  required final PinPadController controller,
  required final VoidCallback onForgotPin,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (:failure, :checking, :lockedUntil) = ref.watch(
      deleteAccountControllerProvider.select(
        (s) => (failure: s.failure, checking: s.submitting, lockedUntil: s.lockedUntil),
      ),
    );
    final notifier = ref.read(deleteAccountControllerProvider.notifier);
    final error = switch (failure) {
      null => null,
      _ when failure.apiCode == ApiErrorCode.pinInvalid => wrongPinMessage(failure),
      _ when failure.apiCode == ApiErrorCode.pinLocked => null,
      _ => failure.displayMessage,
    };

    return CurrentPinEntry(
      headingTop: AppSpace.s8,
      dotsGap: 36,
      headline: l10n.deleteAccountPinHeadline,
      caption: l10n.deleteAccountPinCaption,
      error: error,
      checking: checking,
      controller: controller,
      lockedUntil: lockedUntil,
      onLockFinished: notifier.lockFinished,
      onForgotPin: onForgotPin,
      onCompleted: notifier.enter,
    );
  }
}

/// Step 3: the account is gone.
class const _Done() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(AppIcons.checkCircle, size: 56, color: c.paid.fg),
        const SizedBox(height: AppSpace.s6),
        HeadlineText(l10n.deleteAccountDoneHeadline, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.s2),
        Text(
          l10n.deleteAccountDoneBody,
          textAlign: TextAlign.center,
          style: t.body.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class const _FinishButton() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppButton(
    label: context.l10n.deleteAccountDoneButton,
    block: true,
    onPressed: ref.read(deleteAccountControllerProvider.notifier).finish,
  );
}

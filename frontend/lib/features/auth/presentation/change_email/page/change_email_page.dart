import '../../../../../core/l10n/l10n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/auth_status.dart';
import '../../shared/controllers/auth_session_controller.dart';
import '../../shared/widgets/auth_scaffold.dart';
import '../../forgot_pin/page/forgot_pin_page.dart';
import '../../shared/widgets/pin_entry.dart';
import '../../shared/widgets/step_pills.dart';
import '../../verify_otp/controllers/email_otp_controller.dart';
import '../../verify_otp/page/verify_otp_page.dart';
import '../controllers/change_email_controller.dart';

class const ChangeEmailPage({super.key, required final VoidCallback onDone, required final VoidCallback onForgotPin})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState() extends ConsumerState<ChangeEmailPage> {
  final _email = TextEditingController();
  final _pin = PinPadController();

  /// The format check under the field, before anything is sent.
  final _formatError = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    ref.listenManual(changeEmailControllerProvider, _onState);
    ref.listenManual(emailOtpControllerProvider, _onVerify);
    _email.addListener(_onEditing);
    _pin.addListener(_onTyping);
  }

  @override
  void dispose() {
    _email.dispose();
    _pin.dispose();
    _formatError.dispose();
    super.dispose();
  }

  void _onState(ChangeEmailState? previous, ChangeEmailState next) {
    if (previous?.step != next.step) _pin.clear();
    final failure = next.failure;
    if (failure == null || failure == previous?.failure) return;
    _pin.clear();
    final shownInline = switch (next.step) {
      ChangeEmailStep.email => failure is ValidationFailure || failure is ConflictFailure,
      ChangeEmailStep.pin => failure.apiCode == ApiErrorCode.pinInvalid || failure.apiCode == ApiErrorCode.pinLocked,
      ChangeEmailStep.code => false,
    };
    if (!shownInline) showAppToast(context, failure.displayMessage(context.l10n));
  }

  void _onVerify(AsyncValue<EmailOtpState>? previous, AsyncValue<EmailOtpState> next) {
    if (ref.read(changeEmailControllerProvider).step != ChangeEmailStep.code) return;
    final state = next.value;
    if (state == null) return;
    if (state.result != null && previous?.value?.result == null) {
      showAppToast(context, context.l10n.authEmailChanged);
      widget.onDone();
      return;
    }
    final failure = state.failure;
    if (failure == null || failure == previous?.value?.failure) return;
    switch (failure.apiCode) {
      case ApiErrorCode.otpAlreadyUsed || ApiErrorCode.otpNotFound:
        ref.read(changeEmailControllerProvider.notifier).editEmail();
      case ApiErrorCode.otpInvalid || ApiErrorCode.otpExpired || ApiErrorCode.otpTooManyAttempts:
        break;
      default:
        showAppToast(context, failure.displayMessage(context.l10n));
    }
  }

  void _onEditing() {
    _formatError.value = null;
    ref.read(changeEmailControllerProvider.notifier).clearFailure();
  }

  void _onTyping() {
    if (_pin.value.isNotEmpty) ref.read(changeEmailControllerProvider.notifier).clearFailure();
  }

  void _submitEmail() {
    final email = EmailField.normalize(_email.text);
    if (!EmailField.isValidShape(email)) {
      _formatError.value = context.l10n.widgetEmailFormatError;
      return;
    }
    ref.read(changeEmailControllerProvider.notifier).submitEmail(email);
  }

  void _back() {
    if (!ref.read(changeEmailControllerProvider.notifier).back()) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(changeEmailControllerProvider.select((s) => s.step));

    // The close button leaves the flow; the system back steps back.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AuthScaffold(
        progress: (label: context.l10n.securityChangeEmail, step: step.index + 1, total: ChangeEmailStep.values.length),
        onBack: widget.onDone,
        pinPad: step == ChangeEmailStep.pin,
        bottom: switch (step) {
          ChangeEmailStep.email => _NextButton(onPressed: _submitEmail),
          ChangeEmailStep.pin => null,
          ChangeEmailStep.code => const _SpamHint(),
        },
        bottomPadding: step == ChangeEmailStep.code ? 28 : AppSpace.s6,
        body: switch (step) {
          ChangeEmailStep.email => _EmailStep(
            controller: _email,
            formatError: _formatError,
            onSubmit: _submitEmail,
          ),
          ChangeEmailStep.pin => _PinStep(controller: _pin, onForgotPin: widget.onForgotPin),
          ChangeEmailStep.code => const _CodeStep(),
        },
      ),
    );
  }
}

/// "Email baru · PIN · Kode" under the bar.
class const _Steps({required final ChangeEmailStep step}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StepPills(
    labels: [context.l10n.authNewEmail, context.l10n.authStepPin, context.l10n.authStepCode],
    current: step.index,
  );
}

/// Step 1: "Ganti **email**", the current address and the new one.
class const _EmailStep({
  required final TextEditingController controller,
  required final ValueNotifier<String?> formatError,
  required final VoidCallback onSubmit,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final current = ref.watch(
      authSessionControllerProvider.select(
        (s) => switch (s.value) {
          AuthUnlocked(:final user) || AuthLocked(:final user) => user?.email,
          _ => null,
        },
      ),
    );
    final failure = ref.watch(changeEmailControllerProvider.select((s) => s.failure));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Steps(step: ChangeEmailStep.email),
        const SizedBox(height: AppSpace.s5),
        HeadlineText(context.l10n.authChangeEmailHeadline),
        const SizedBox(height: AppSpace.s2),
        Text(
          context.l10n.authChangeEmailCaption,
          style: t.bodyLg.copyWith(color: c.textSecondary),
        ),
        if (current != null) ...[
          const SizedBox(height: AppSpace.s6),
          Text(context.l10n.authCurrentEmail, style: t.caption.copyWith(color: c.textTertiary)),
          const SizedBox(height: AppSpace.s1),
          Text(current, style: t.bodyLg.copyWith(color: c.textPrimary)),
        ],
        const SizedBox(height: AppSpace.s6),
        ValueListenableBuilder(
          valueListenable: formatError,
          builder: (context, format, _) => EmailField(
            controller: controller,
            label: context.l10n.authNewEmail,
            autofocus: true,
            errorText: format ?? newEmailErrorMessage(context.l10n, failure),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
      ],
    );
  }
}

/// "Lanjut", docked above the keyboard on step 1.
class const _NextButton({required final VoidCallback onPressed}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitting = ref.watch(changeEmailControllerProvider.select((s) => s.submitting));

    return AppButton(label: context.l10n.nextButton, block: true, loading: submitting, onPressed: onPressed);
  }
}

/// Step 2: the current PIN, sent with the code request.
class const _PinStep({required final PinPadController controller, required final VoidCallback onForgotPin})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:failure, :submitting, :lockedUntil) = ref.watch(
      changeEmailControllerProvider.select(
        (s) => (failure: s.failure, submitting: s.submitting, lockedUntil: s.lockedUntil),
      ),
    );
    final notifier = ref.read(changeEmailControllerProvider.notifier);

    return CurrentPinEntry(
      top: const _Steps(step: ChangeEmailStep.pin),
      headingTop: AppSpace.s8,
      dotsGap: 36,
      headline: context.l10n.authPinHeadline,
      caption: context.l10n.authPinCaption,
      error: wrongPinMessage(context.l10n, failure),
      controller: controller,
      checking: submitting,
      lockedUntil: lockedUntil,
      onLockFinished: notifier.lockFinished,
      onForgotPin: onForgotPin,
      onCompleted: notifier.submitPin,
    );
  }
}

/// Step 3: "Masukkan kode dari **email baru** kamu", the code card and the
/// notice that the old address hears about it.
class const _CodeStep() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(emailOtpControllerProvider).value;
    final challenge = state?.pending?.challenge;
    if (challenge == null) return const SizedBox.shrink();
    final oldEmail = ref.watch(
      authSessionControllerProvider.select(
        (s) => switch (s.value) {
          AuthUnlocked(:final user) || AuthLocked(:final user) => user?.email,
          _ => null,
        },
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Steps(step: ChangeEmailStep.code),
        const SizedBox(height: AppSpace.s5),
        HeadlineText(context.l10n.authNewEmailCodeHeadline),
        const SizedBox(height: AppSpace.s4),
        _CodeCard(sentTo: state?.pending?.email ?? challenge.emailMasked ?? ''),
        const SizedBox(height: 14),
        AppBanner(
          note: true,
          variant: AppBannerVariant.warning,
          icon: AppIcons.warningCircle,
          message: oldEmail == null
              ? context.l10n.authOldEmailNotified
              : context.l10n.authOldEmailNotifiedTo(maskEmail(oldEmail)),
        ),
      ],
    );
  }
}

/// The white card: where the code went, the six boxes, the timers and
/// "Buka aplikasi email", or the reason and one action once the code is
/// expired or locked.
class const _CodeCard({required final String sentTo}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final state = ref.watch(emailOtpControllerProvider).value;
    final challenge = state?.pending?.challenge;
    final (cardState, message) = emailCodeCardStateOf(context.l10n, state);
    final notifier = ref.read(emailOtpControllerProvider.notifier);
    final editEmail = ref.read(changeEmailControllerProvider.notifier).editEmail;
    final resending = state?.resending ?? false;
    final closed = cardState == EmailCodeCardState.expired || cardState == EmailCodeCardState.locked;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ShapeDecoration(color: c.surface, shape: AppShapes.squircle(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          _SentTo(email: sentTo),
          if (closed)
            OtpClosedState(
              expired: cardState == EmailCodeCardState.expired,
              message: message,
              resending: resending,
              onRequestNew: notifier.resend,
              onRestart: editEmail,
            )
          else ...[
            OtpInput(
              onCard: true,
              error: cardState == EmailCodeCardState.wrong,
              checking: cardState == EmailCodeCardState.checking || cardState == EmailCodeCardState.success,
              onCompleted: notifier.verify,
            ),
            if (message != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: t.caption.copyWith(
                    color: cardState == EmailCodeCardState.wrong ? c.rejected.fg : c.paid.fg,
                  ),
                ),
              ),
            if (cardState != EmailCodeCardState.success) ...[
              OtpTimers(
                expiresAt: challenge?.expiresAt,
                resendAvailableAt: challenge?.resendAvailableAt,
                resending: resending,
                onResend: notifier.resend,
              ),
              // A 48 high secondary, between the regular and small sizes.
              SizedBox(
                height: 48,
                child: AppButton.secondary(
                  label: context.l10n.authOpenMailApp,
                  icon: AppIcons.envelopeSimple,
                  block: true,
                  onPressed: () => openMailApp(context, ref),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// An envelope on `bg.subtle`, "Kode dikirim ke" and the new address.
class const _SentTo({required final String email}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return Row(
      spacing: AppSpace.s3,
      children: [
        Container(
          width: AppSizes.avatarMd,
          height: AppSizes.avatarMd,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.subtle, shape: BoxShape.circle),
          child: AppIcon(AppIcons.envelopeSimple, size: AppSizes.iconMd, color: c.textPrimary),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.authCodeSentTo, style: t.caption.copyWith(color: c.textTertiary)),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.title.copyWith(color: c.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Tidak ada di kotak masuk? Cek folder Spam atau Promosi." at the bottom
/// of step 3.
class const _SpamHint() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
    child: Text(
      context.l10n.authSpamHint,
      textAlign: TextAlign.center,
      style: AppTextStyles.of(context).caption.copyWith(color: context.colors.textTertiary),
    ),
  );
}

/// Step 1 copy for a rejected new address: the same address, a taken one
/// (`email_already_registered`) or the server's field error.
String? newEmailErrorMessage(AppLocalizations l10n, Failure? failure) => switch (failure) {
  null => null,
  ConflictFailure(code: ApiErrorCode.emailAlreadyRegistered) => l10n.authEmailTaken,
  ValidationFailure() => failure.fieldMessage('email') ?? failure.displayMessage(l10n),
  _ => null,
};

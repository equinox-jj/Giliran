import '../../../../../core/l10n/l10n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../core/utils/enums/otp_purpose.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../set_pin/page/set_pin_page.dart';
import '../../shared/widgets/auth_scaffold.dart';
import '../../shared/widgets/pin_entry.dart';
import '../../sign_in/controllers/email_otp_request_controller.dart';
import '../../verify_otp/controllers/email_otp_controller.dart';
import '../../verify_otp/page/verify_otp_page.dart';

enum ForgotPinStep() {
  /// "Kami kirim kode ke …" and "Kirim kode".
  explain,

  /// The email code card; the code is only collected here.
  code,

  /// The new PIN twice, then one verify with code and PIN.
  newPin,
}

class const ForgotPinPage({
  super.key,
  required final VoidCallback onBack,
  final String? email,
  final VoidCallback? onDone,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<ForgotPinPage> createState() => _ForgotPinPageState();
}

class _ForgotPinPageState() extends ConsumerState<ForgotPinPage> {
  final _step = ValueNotifier(ForgotPinStep.explain);
  final _firstPin = ValueNotifier<String?>(null);
  final _pinError = ValueNotifier<String?>(null);
  final _pin = PinPadController();
  String? _code;

  @override
  void initState() {
    super.initState();
    ref.listenManual(emailOtpControllerProvider, _onVerify);
    // The first digit of a new entry clears the last error.
    _pin.addListener(() {
      if (_pin.value.isNotEmpty) _pinError.value = null;
    });
  }

  @override
  void dispose() {
    _step.dispose();
    _firstPin.dispose();
    _pinError.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _onVerify(AsyncValue<EmailOtpState>? previous, AsyncValue<EmailOtpState> next) {
    final state = next.value;
    if (state == null) return;
    if (state.result != null && previous?.value?.result == null) {
      showAppToast(context, context.l10n.authPinReset);
      widget.onDone?.call();
      return;
    }

    final failure = state.failure;
    if (failure == null || failure == previous?.value?.failure) return;
    _restartPin();
    switch (failure.apiCode) {
      case ApiErrorCode.otpInvalid ||
          ApiErrorCode.otpExpired ||
          ApiErrorCode.otpTooManyAttempts ||
          ApiErrorCode.otpAlreadyUsed ||
          ApiErrorCode.otpNotFound:
        _step.value = ForgotPinStep.code;
      case ApiErrorCode.validationError:
        _pinError.value = setPinErrorMessage(context.l10n, failure);
      default:
        showAppToast(context, failure.displayMessage(context.l10n));
    }
  }

  void _restartPin() {
    _firstPin.value = null;
    _pin.clear();
  }

  Future<void> _sendCode() async {
    final email = widget.email;
    if (email == null) return;
    final sent = await ref
        .read(emailOtpRequestControllerProvider.notifier)
        .request(purpose: OtpPurpose.resetPin, email: email);
    if (!mounted) return;
    if (!sent) {
      final failure = ref.read(emailOtpRequestControllerProvider).error;
      if (failure is Failure) showAppToast(context, failure.displayMessage(context.l10n));
      return;
    }
    // Reload the code screen from the request just saved.
    ref.invalidate(emailOtpControllerProvider);
    _step.value = ForgotPinStep.code;
  }

  void _onCode(String code) {
    _code = code;
    _pinError.value = null;
    _restartPin();
    _step.value = ForgotPinStep.newPin;
  }

  void _onPin(String pin) {
    final first = _firstPin.value;
    final code = _code;
    if (first == null) {
      _firstPin.value = pin;
      _pinError.value = null;
      _pin.clear();
      return;
    }
    if (code == null) return;
    ref.read(emailOtpControllerProvider.notifier).verify(code, newPin: first, newPinConfirmation: pin);
  }

  void _back() {
    switch (_step.value) {
      case ForgotPinStep.explain:
        widget.onBack();
      case ForgotPinStep.code:
        _step.value = ForgotPinStep.explain;
      case ForgotPinStep.newPin:
        _step.value = ForgotPinStep.code;
    }
  }

  @override
  Widget build(BuildContext context) {
    // The close button leaves the flow; the system back steps back.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ValueListenableBuilder(
        valueListenable: _step,
        builder: (context, step, _) => AuthScaffold(
          progress: (label: context.l10n.authForgotPinTitle, step: step.index + 1, total: ForgotPinStep.values.length),
          onBack: widget.onBack,
          topPadding: step == ForgotPinStep.explain ? AppSpace.s4 : AppSpace.s2,
          centerBody: step == ForgotPinStep.code,
          pinPad: step == ForgotPinStep.newPin,
          bottom: step == ForgotPinStep.explain ? _SendButton(email: widget.email, onSend: _sendCode) : null,
          body: switch (step) {
            ForgotPinStep.explain => _Explain(email: widget.email),
            ForgotPinStep.code => _CodeStep(onCompleted: _onCode, onRestart: () => _step.value = ForgotPinStep.explain),
            ForgotPinStep.newPin => _NewPinStep(
              controller: _pin,
              firstPin: _firstPin,
              error: _pinError,
              onCompleted: _onPin,
            ),
          },
        ),
      ),
    );
  }
}

/// Step 1: "Pastikan **ini kamu**", where the code goes and the three steps
/// ahead.
class const _Explain({required final String? email}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final email = this.email;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeadlineText(context.l10n.authForgotHeadline),
        const SizedBox(height: 10),
        Text(
          email == null ? context.l10n.authForgotNoEmail : context.l10n.authForgotCaption,
          style: t.body.copyWith(color: c.textSecondary),
        ),
        if (email != null) ...[
          const SizedBox(height: 18),
          _SendTarget(emailMasked: maskEmail(email)),
        ],
        const SizedBox(height: AppSpace.s4),
        const _StepList(),
      ],
    );
  }
}

/// The ink-outlined card: an envelope, "Kode dikirim ke" and the masked
/// address.
class const _SendTarget({required final String emailMasked}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: c.ink, width: AppStroke.strong, strokeAlign: BorderSide.strokeAlignInside),
        ),
      ),
      child: Row(
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
              spacing: 2,
              children: [
                Text(context.l10n.authCodeSentTo, style: t.caption.copyWith(color: c.textTertiary)),
                Text(
                  emailMasked,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleLg.copyWith(fontSize: 18, letterSpacing: 0.1, color: c.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The three steps of the flow in a white card, the first one current.
class const _StepList() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final steps = [
      (l10n.authForgotStepCode, l10n.authForgotStepCodeHint),
      (l10n.authForgotStepPin, l10n.authForgotStepPinHint),
      (l10n.authForgotStepDone, l10n.authForgotStepDoneHint),
    ];

    return Container(
      decoration: ShapeDecoration(color: c.surface, shape: AppShapes.squircle(AppRadius.lg)),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.hairline),
            _StepRow(number: i + 1, title: steps[i].$1, caption: steps[i].$2, current: i == 0),
          ],
        ],
      ),
    );
  }
}

/// One step: a 28 number circle (ink when [current], dashed otherwise), the
/// title and a caption.
class const _StepRow({
  required final int number,
  required final String title,
  required final String caption,
  required final bool current,
}) extends StatelessWidget {
  static const _dot = 28.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final digit = t.body.copyWith(fontSize: 13, height: 1, fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          if (current)
            Container(
              width: _dot,
              height: _dot,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.inverse, shape: BoxShape.circle),
              child: Text('$number', style: digit.copyWith(color: c.textOnInverse)),
            )
          else
            DashedBorder.circle(
              color: c.borderStrong,
              child: SizedBox.square(
                dimension: _dot,
                child: Center(
                  child: Text('$number', style: digit.copyWith(color: c.textTertiary)),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                    color: current ? c.textPrimary : c.textSecondary,
                  ),
                ),
                Text(caption, style: t.caption.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Kirim kode ke email", docked, with the help line under it.
class const _SendButton({required final String? email, required final VoidCallback onSend}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final loading = ref.watch(
      emailOtpRequestControllerProvider.select((s) => s.isLoading),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        AppButton(
          label: context.l10n.authSendCodeToEmail,
          block: true,
          loading: loading,
          onPressed: email == null ? null : onSend,
        ),
        // Plain caption in the design; it still opens the recovery help.
        Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showHelpSheet(
              context,
              title: context.l10n.authNoEmailTitle,
              paragraphs: [context.l10n.authNoEmailBody1, context.l10n.authNoEmailBody2],
            ),
            child: Text(
              context.l10n.authNoEmailLink,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: c.textTertiary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Step 2: the email code card. The code is checked together with the new
/// PIN, so a wrong code comes back here after step 3.
class const _CodeStep({
  required final ValueChanged<String> onCompleted,
  required final VoidCallback onRestart,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(emailOtpControllerProvider).value;
    final challenge = state?.pending?.challenge;
    if (challenge == null) return const SizedBox.shrink();
    final (cardState, message) = emailCodeCardStateOf(context.l10n, state);
    final notifier = ref.read(emailOtpControllerProvider.notifier);

    return EmailCodeCard(
      emailMasked: challenge.emailMasked ?? '',
      state: cardState,
      message: message,
      onCompleted: onCompleted,
      resendAvailableAt: challenge.resendAvailableAt,
      resending: state?.resending ?? false,
      onResend: notifier.resend,
      onRequestNew: notifier.resend,
      onRestart: onRestart,
      onOpenMail: () => openMailApp(context, ref),
    );
  }
}

class const _NewPinStep({
  required final PinPadController controller,
  required final ValueNotifier<String?> firstPin,
  required final ValueNotifier<String?> error,
  required final ValueChanged<String> onCompleted,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitting = ref.watch(
      emailOtpControllerProvider.select((s) => s.value?.submitting ?? false),
    );

    return ListenableBuilder(
      listenable: Listenable.merge([firstPin, error]),
      builder: (context, _) => PinEntry(
        headline: firstPin.value == null ? context.l10n.authNewPinHeadline : context.l10n.authNewPinConfirmHeadline,
        caption: context.l10n.authOldPinInvalid,
        error: error.value,
        controller: controller,
        checking: submitting,
        onCompleted: onCompleted,
      ),
    );
  }
}

/// "rina@gmail.com" → "ri•••••@gmail.com", the same shape as the API's
/// `email_masked`.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final visible = email.substring(0, at < 2 ? at : 2);
  return '$visible•••••${email.substring(at)}';
}

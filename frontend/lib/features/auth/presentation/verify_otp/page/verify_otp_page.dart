import '../../../../../core/l10n/l10n.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/services/mail_app_launcher.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../shared/widgets/auth_scaffold.dart';
import '../../shared/widgets/pin_entry.dart';
import '../controllers/email_otp_controller.dart';

class const VerifyOtpPage({
  super.key,
  required final ValueChanged<String?> onChangeEmail,
  required final ValueChanged<String?> onForgotPin,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState() extends ConsumerState<VerifyOtpPage> {
  final _pin = PinPadController();
  final _pinLockedUntil = ValueNotifier<DateTime?>(null);
  String? _code;

  @override
  void initState() {
    super.initState();
    ref.listenManual(emailOtpControllerProvider, _onState);
  }

  @override
  void dispose() {
    _pin.dispose();
    _pinLockedUntil.dispose();
    super.dispose();
  }

  void _onState(AsyncValue<EmailOtpState>? previous, AsyncValue<EmailOtpState> next) {
    if (next.isLoading || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final state = next.value;
    final email = state?.pending?.email;
    if (next.hasError || state?.pending == null) {
      widget.onChangeEmail(email);
      return;
    }

    final failure = state?.failure;
    if (failure == null || failure == previous?.value?.failure) return;
    switch (failure.apiCode) {
      case ApiErrorCode.otpAlreadyUsed || ApiErrorCode.otpNotFound:
        widget.onChangeEmail(email);
      case ApiErrorCode.pinInvalid:
        _pin.clear();
      case ApiErrorCode.pinLocked:
        _pin.clear();
        final wait = failure.retryAfterDelay;
        if (wait != null) _pinLockedUntil.value = DateTime.now().add(wait);
      case ApiErrorCode.pinRequired || ApiErrorCode.otpInvalid || ApiErrorCode.otpExpired:
        break;
      default:
        if (failure.apiCode != ApiErrorCode.otpTooManyAttempts) {
          showAppToast(context, failure.displayMessage(context.l10n));
        }
    }
  }

  void _verifyCode(String code) {
    _code = code;
    ref.read(emailOtpControllerProvider.notifier).verify(code);
  }

  void _verifyPin(String pin) {
    final code = _code;
    if (code == null) return;
    ref.read(emailOtpControllerProvider.notifier).verify(code, pin: pin);
  }

  @override
  Widget build(BuildContext context) {
    final pinStep = ref.watch(emailOtpControllerProvider.select((s) => s.value?.pinRequired ?? false));

    return AuthScaffold(
      pinPad: pinStep,
      topPadding: pinStep ? AppSpace.s1 : AppSpace.s2,
      onBack: () => widget.onChangeEmail(ref.read(emailOtpControllerProvider).value?.pending?.email),
      body: _Body(
        pin: _pin,
        pinLockedUntil: _pinLockedUntil,
        onVerifyCode: _verifyCode,
        onVerifyPin: _verifyPin,
        onChangeEmail: widget.onChangeEmail,
        onForgotPin: widget.onForgotPin,
      ),
    );
  }
}

class const _Body({
  required final PinPadController pin,
  required final ValueNotifier<DateTime?> pinLockedUntil,
  required final ValueChanged<String> onVerifyCode,
  required final ValueChanged<String> onVerifyPin,
  required final ValueChanged<String?> onChangeEmail,
  required final ValueChanged<String?> onForgotPin,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(emailOtpControllerProvider).value;
    final email = state?.pending?.email;
    final challenge = state?.pending?.challenge;
    if (state == null || challenge == null) return const SizedBox.shrink();

    final emailMasked = challenge.emailMasked ?? email ?? '';
    if (state.pinRequired) {
      return _PinStep(
        emailMasked: emailMasked,
        controller: pin,
        failure: state.failure,
        submitting: state.submitting,
        lockedUntil: pinLockedUntil,
        onCompleted: onVerifyPin,
        onForgotPin: () => onForgotPin(email),
      );
    }

    final (cardState, message) = emailCodeCardStateOf(context.l10n, state);
    final notifier = ref.read(emailOtpControllerProvider.notifier);
    return _CodeStep(
      emailMasked: emailMasked,
      state: cardState,
      message: message,
      expiresAt: challenge.expiresAt,
      resendAvailableAt: challenge.resendAvailableAt,
      resending: state.resending,
      onCompleted: onVerifyCode,
      onChangeEmail: () => onChangeEmail(email),
      onResend: notifier.resend,
      onOpenMail: () => openMailApp(context, ref),
    );
  }
}

class const _CodeStep({
  required final String emailMasked,
  required final EmailCodeCardState state,
  required final String? message,
  required final DateTime? expiresAt,
  required final DateTime? resendAvailableAt,
  required final bool resending,
  required final ValueChanged<String> onCompleted,
  required final VoidCallback onChangeEmail,
  required final VoidCallback onResend,
  required final VoidCallback onOpenMail,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final closed = state == EmailCodeCardState.expired || state == EmailCodeCardState.locked;
    final message = this.message;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeadlineText(context.l10n.authOtpHeadline),
        const SizedBox(height: AppSpace.s4),
        _SentTo(emailMasked: emailMasked, onChange: onChangeEmail),
        const SizedBox(height: AppSpace.s6),
        if (closed)
          OtpClosedState(
            expired: state == EmailCodeCardState.expired,
            message: message,
            resending: resending,
            onRequestNew: onResend,
            onRestart: onChangeEmail,
          )
        else ...[
          OtpInput(
            error: state == EmailCodeCardState.wrong,
            checking: state == EmailCodeCardState.checking || state == EmailCodeCardState.success,
            onCompleted: onCompleted,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpace.s3),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: t.caption.copyWith(
                  color: state == EmailCodeCardState.wrong ? c.rejected.fg : c.paid.fg,
                ),
              ),
            ),
          ],
          if (state != EmailCodeCardState.success) ...[
            const SizedBox(height: AppSpace.s3),
            OtpTimers(
              expiresAt: expiresAt,
              resendAvailableAt: resendAvailableAt,
              resending: resending,
              onResend: onResend,
            ),
            const SizedBox(height: AppSpace.s5),
            AppButton.secondary(
              label: context.l10n.authOpenMailApp,
              icon: AppIcons.envelopeSimple,
              block: true,
              onPressed: onOpenMail,
            ),
          ],
        ],
        const SizedBox(height: AppSpace.s3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
          child: Text(
            context.l10n.authSpamHint,
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: c.textTertiary),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        AppBanner(
          message: context.l10n.authOtpNeverShare,
          variant: AppBannerVariant.warning,
          icon: AppIcons.shieldWarning,
          note: true,
        ),
      ],
    );
  }
}

/// The white card: an envelope on the hero tone, "Kode 6 digit dikirim ke",
/// the masked address and "Ubah".
class const _SentTo({required final String emailMasked, required final VoidCallback onChange}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return Container(
      // "Ubah" brings its own 18 px side padding, so 4 here lands its label
      // 22 px in from the edge.
      padding: const EdgeInsets.fromLTRB(18, AppSpace.s4, AppSpace.s1, AppSpace.s4),
      decoration: ShapeDecoration(color: c.surface, shape: AppShapes.squircle(AppRadius.lg)),
      child: Row(
        children: [
          Container(
            width: AppSizes.circleButton,
            height: AppSizes.circleButton,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.hero, shape: BoxShape.circle),
            child: AppIcon(AppIcons.envelopeSimple, size: AppSizes.iconCircleButton, color: c.textPrimary),
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.authCodeSentTo6, style: t.caption.copyWith(color: c.textTertiary)),
                Text(
                  emailMasked,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.title.copyWith(color: c.textPrimary),
                ),
              ],
            ),
          ),
          AppButton.link(
            label: context.l10n.editLink,
            semanticLabel: context.l10n.securityChangeEmail,
            size: AppButtonSize.small,
            onPressed: onChange,
          ),
        ],
      ),
    );
  }
}

/// "Berlaku 09:48" on the left and "Kirim ulang dalam 0:52" on the right,
/// ticking every second. The right side becomes "Kirim ulang" once
/// `resend_available_at` has passed.
class const OtpTimers({
  super.key,
  required final DateTime? expiresAt,
  required final DateTime? resendAvailableAt,
  required final bool resending,
  required final VoidCallback onResend,
}) extends StatefulWidget {
  @override
  State<OtpTimers> createState() => _OtpTimersState();
}

class _OtpTimersState() extends State<OtpTimers> {
  Timer? _timer;

  static Duration? _left(DateTime? until) {
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  static String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(OtpTimers old) {
    super.didUpdateWidget(old);
    if (old.expiresAt != widget.expiresAt || old.resendAvailableAt != widget.resendAvailableAt) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    if (_left(widget.expiresAt) == null && _left(widget.resendAvailableAt) == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_left(widget.expiresAt) == null && _left(widget.resendAvailableAt) == null) timer.cancel();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final caption = t.caption.copyWith(color: c.textTertiary, fontFeatures: AppTextStyles.tabularFigures);
    final expires = _left(widget.expiresAt);
    final resend = _left(widget.resendAvailableAt);

    return Row(
      children: [
        if (expires != null)
          Text.rich(
            TextSpan(
              text: context.l10n.authOtpValidPrefix,
              children: [
                TextSpan(
                  text: _clock(expires),
                  style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            style: caption,
          ),
        const Spacer(),
        if (resend != null)
          Text(context.l10n.authResendIn(_clock(resend)), style: caption)
        else
          AppButton.link(
            label: context.l10n.authResend,
            size: AppButtonSize.xsmall,
            loading: widget.resending,
            onPressed: widget.onResend,
          ),
      ],
    );
  }
}

/// Expired or locked: the reason and one primary action in place of the
/// boxes.
class const OtpClosedState({
  super.key,
  required final bool expired,
  required final String? message,
  required final bool resending,
  required final VoidCallback onRequestNew,
  required final VoidCallback onRestart,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBanner(
          message: message ?? (expired ? context.l10n.authCodeExpired : context.l10n.authCodeLocked),
          variant: expired ? AppBannerVariant.offline : AppBannerVariant.error,
          icon: expired ? AppIcons.hourglassMedium : AppIcons.warningCircle,
        ),
        const SizedBox(height: AppSpace.s4),
        if (expired)
          AppButton(label: context.l10n.authSendNewCode, block: true, loading: resending, onPressed: onRequestNew)
        else
          AppButton(label: context.l10n.authRequestNewCode, block: true, onPressed: onRestart),
      ],
    );
  }
}

Future<void> openMailApp(BuildContext context, WidgetRef ref) async {
  final opened = await ref.read(mailAppLauncherProvider).open();
  if (!opened && context.mounted) {
    showAppToast(context, context.l10n.authMailAppFailed);
  }
}

(EmailCodeCardState, String?) emailCodeCardStateOf(AppLocalizations l10n, EmailOtpState? state) {
  if (state == null) return (EmailCodeCardState.waiting, null);
  if (state.result != null) return (EmailCodeCardState.success, l10n.authCodeCorrect);
  if (state.submitting) return (EmailCodeCardState.checking, null);

  final failure = state.failure;
  return switch (failure?.apiCode) {
    ApiErrorCode.otpInvalid => (
      EmailCodeCardState.wrong,
      switch (failure?.attemptsRemaining) {
        final n? => l10n.authCodeWrongLeft(n),
        null => l10n.authCodeWrong,
      },
    ),
    ApiErrorCode.otpExpired => (EmailCodeCardState.expired, l10n.authCodeExpired),
    ApiErrorCode.otpTooManyAttempts => (
      EmailCodeCardState.locked,
      l10n.authCodeLocked,
    ),
    _ => (EmailCodeCardState.waiting, null),
  };
}

class const _PinStep({
  required final String emailMasked,
  required final PinPadController controller,
  required final Failure? failure,
  required final bool submitting,
  required final ValueNotifier<DateTime?> lockedUntil,
  required final ValueChanged<String> onCompleted,
  required final VoidCallback onForgotPin,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final wrongPin = failure?.apiCode == ApiErrorCode.pinInvalid;
    final attempts = failure?.attemptsRemaining;
    final header = _PinHeading(emailMasked: emailMasked);
    final footer = _ForgotPinLink(onPressed: onForgotPin);

    return ValueListenableBuilder(
      valueListenable: lockedUntil,
      builder: (context, until, _) => until != null
          ? PinCountdownLayout(
              header: header,
              countdown: CountdownText.lock(
                until: until,
                caption: context.l10n.authPinLockedCaption,
                onFinished: () => lockedUntil.value = null,
              ),
              footer: footer,
            )
          : PinPad(
              controller: controller,
              error: wrongPin,
              checking: submitting,
              expand: true,
              onCompleted: onCompleted,
              header: header,
              footer: footer,
              belowDots: PinErrorLine(
                message: !wrongPin
                    ? null
                    : attempts == null
                    ? context.l10n.authPinWrong
                    : context.l10n.authPinWrongTriesLeft(attempts),
              ),
            ),
    );
  }
}

/// "Kode benar" and "Masukkan **PIN** kamu" over the dots.
class const _PinHeading({required final String emailMasked}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CodeAccepted(emailMasked: emailMasked),
        const SizedBox(height: 28),
        HeadlineText(context.l10n.authPinHeadline, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.s2),
        Text(
          context.l10n.authPinCaption,
          textAlign: TextAlign.center,
          style: t.body.copyWith(color: c.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// "Lupa PIN?" under the pad.
class const _ForgotPinLink({required final VoidCallback onPressed}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: AppSpace.s4),
      AppButton.link(label: context.l10n.authForgotPin, size: AppButtonSize.small, onPressed: onPressed),
      const SizedBox(height: AppSpace.s1),
    ],
  );
}

/// The `paid` banner on the PIN step: a check, "Kode benar" and the address.
class const _CodeAccepted({required final String emailMasked}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: 14),
        decoration: ShapeDecoration(color: c.paid.bg, shape: AppShapes.squircle(AppRadius.lg)),
        child: Row(
          children: [
            AppIcon(AppIcons.checkCircleFill, size: AppSizes.iconLg, color: c.paid.fg),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.authCodeCorrect,
                    style: t.bodyLg.copyWith(color: c.paid.fg, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    emailMasked,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: c.paid.fg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

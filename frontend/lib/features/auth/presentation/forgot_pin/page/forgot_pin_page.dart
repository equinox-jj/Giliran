import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_illustrations.dart';
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

/// The three steps of S09.
enum ForgotPinStep() {
  /// "Kami kirim kode ke …" and "Kirim kode".
  explain,

  /// The email code card; the code is only collected here.
  code,

  /// The new PIN twice, then one verify with code and PIN.
  newPin,
}

/// S09 Forgot PIN: sends a `reset_pin` code to the account's [email], takes
/// the code and a new PIN, and verifies them together. Success signs this
/// device in again and the guard moves on, or [onDone] runs when the flow
/// was opened from an open session (S45, S46).
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
      showAppToast(context, 'PIN baru tersimpan. Perangkat lain sudah dikeluarkan.');
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
        _pinError.value = setPinErrorMessage(failure);
      default:
        showAppToast(context, failure.displayMessage);
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
      if (failure is Failure) showAppToast(context, failure.displayMessage);
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
    return ValueListenableBuilder(
      valueListenable: _step,
      builder: (context, step, _) => AuthScaffold(
        title: 'Lupa PIN',
        onBack: _back,
        centerBody: step != ForgotPinStep.explain,
        pinPad: step == ForgotPinStep.newPin,
        body: switch (step) {
          ForgotPinStep.explain => _Explain(email: widget.email, onSend: _sendCode),
          ForgotPinStep.code => _CodeStep(onCompleted: _onCode, onRestart: () => _step.value = ForgotPinStep.explain),
          ForgotPinStep.newPin => _NewPinStep(
            controller: _pin,
            firstPin: _firstPin,
            error: _pinError,
            onCompleted: _onPin,
          ),
        },
      ),
    );
  }
}

/// Step 1: where the code goes, "Kirim kode" and "Tidak bisa buka email?".
class const _Explain({required final String? email, required final VoidCallback onSend}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final loading = ref.watch(
      emailOtpRequestControllerProvider.select((s) => s.isLoading),
    );
    final email = this.email;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Illustration(AppIllustrations.emailSlip, width: 96, height: 96),
        const SizedBox(height: AppSpace.s6),
        const HeadlineText('Atur ulang **PIN** kamu'),
        const SizedBox(height: AppSpace.s2),
        Text(
          email == null
              ? 'Email akun tidak ditemukan di perangkat ini. Masuk lagi dengan email.'
              : 'Kami kirim kode ke ${maskEmail(email)} untuk memastikan ini kamu.',
          style: t.bodyLg.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpace.s8),
        AppButton(
          label: 'Kirim kode',
          block: true,
          loading: loading,
          onPressed: email == null ? null : onSend,
        ),
        const SizedBox(height: AppSpace.s2),
        AppButton.ghost(
          label: 'Tidak bisa buka email?',
          block: true,
          size: AppButtonSize.small,
          onPressed: () => showHelpSheet(
            context,
            title: 'Tidak bisa buka email?',
            paragraphs: const [
              'PIN hanya bisa diatur ulang lewat kode dari email akunmu. '
                  'Tanpa email itu, akun tidak bisa dipulihkan.',
              'Pengurus arisan tetap bisa mencatat kamu di grup sebagai '
                  'anggota tamu, jadi iuranmu tidak hilang.',
            ],
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
    final (cardState, message) = emailCodeCardStateOf(state);
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

/// Step 3: the S06 layout for the new PIN, twice.
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
        headline: firstPin.value == null ? 'Buat **PIN baru**' : 'Ulangi **PIN baru**',
        caption: 'PIN lama tidak bisa dipakai lagi.',
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

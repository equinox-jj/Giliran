import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_illustrations.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/otp_purpose.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../shared/widgets/auth_scaffold.dart';
import '../controllers/email_otp_request_controller.dart';

/// S03 Sign in with email: one field, "Kirim kode", then [onCodeSent] opens
/// S04. [initialEmail] prefills the field when coming back via "Ubah".
class const SignInPage({
  super.key,
  required final VoidCallback onCodeSent,
  final String? initialEmail,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState() extends ConsumerState<SignInPage> {
  late final _email = TextEditingController(text: widget.initialEmail);

  /// Format or server error under the field.
  final _error = ValueNotifier<String?>(null);

  /// End of the `429` wait; the button is off until then.
  final _retryUntil = ValueNotifier<DateTime?>(null);

  @override
  void initState() {
    super.initState();
    _email.addListener(_clearError);
  }

  @override
  void dispose() {
    _email
      ..removeListener(_clearError)
      ..dispose();
    _error.dispose();
    _retryUntil.dispose();
    super.dispose();
  }

  void _clearError() => _error.value = null;

  Future<void> _submit() async {
    if (_retryUntil.value != null) return;
    final email = EmailField.normalize(_email.text);
    if (!EmailField.isValidShape(email)) {
      _error.value = EmailField.formatError;
      return;
    }

    final controller = ref.read(emailOtpRequestControllerProvider.notifier);
    final sent = await controller.request(
      purpose: OtpPurpose.signIn,
      email: email,
    );
    if (!mounted) return;
    if (sent) {
      widget.onCodeSent();
      return;
    }
    if (ref.read(emailOtpRequestControllerProvider).error case final Failure failure) {
      _showFailure(failure);
    }
  }

  void _showFailure(Failure failure) {
    switch (failure) {
      case TooManyRequestsFailure():
        final wait = failure.retryAfterDelay;
        if (wait != null) {
          _retryUntil.value = DateTime.now().add(wait);
        } else {
          _error.value = failure.displayMessage;
        }
      case NetworkFailure() || TimeoutFailure() || ServerFailure() || UnknownFailure():
        showAppToast(
          context,
          failure.displayMessage,
          actionLabel: 'Coba lagi',
          onAction: _submit,
        );
      default:
        _error.value = failure.fieldMessage('email') ?? failure.displayMessage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = _Form(
      email: _email,
      error: _error,
      retryUntil: _retryUntil,
      onSubmit: _submit,
    );

    return AuthScaffold(
      maxWidth: context.isCompact ? AuthScaffold.formMax : AppSizes.boardMax,
      body: context.isCompact ? form : _WideLayout(form: form),
      bottom: _SendButton(retryUntil: _retryUntil, onSubmit: _submit),
    );
  }
}

/// Tablet: the illustration left, the form right (max width 420).
class const _WideLayout({required final Widget form}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: context.gutter,
      children: [
        const Expanded(child: Center(child: Illustration(AppIllustrations.emailSlip, width: 200, height: 200))),
        Expanded(
          child: MaxWidth(width: AuthScaffold.formMax, child: form),
        ),
      ],
    );
  }
}

class const _Form({
  required final TextEditingController email,
  required final ValueNotifier<String?> error,
  required final ValueNotifier<DateTime?> retryUntil,
  required final VoidCallback onSubmit,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (context.isCompact) ...[
          const Illustration(AppIllustrations.emailSlip, width: 96, height: 96),
          const SizedBox(height: AppSpace.s6),
        ],
        const HeadlineText('Masuk dengan **email**'),
        const SizedBox(height: AppSpace.s2),
        Text(
          'Kami kirim kode 6 digit ke email kamu. Tidak perlu kata sandi.',
          style: t.bodyLg.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpace.s6),
        ValueListenableBuilder(
          valueListenable: error,
          builder: (context, error, _) => EmailField(
            controller: email,
            errorText: error,
            autofocus: true,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        _RetryCountdown(retryUntil: retryUntil),
        const SizedBox(height: AppSpace.s4),
        Text(
          'Dengan lanjut, kamu setuju dengan Syarat & Kebijakan Privasi '
          'di giliran.monai.my.id/privacy.',
          style: t.caption.copyWith(color: c.textTertiary),
        ),
        const SizedBox(height: AppSpace.s2),
        AppButton.ghost(
          label: 'Tidak punya email?',
          size: AppButtonSize.small,
          onPressed: () => showHelpSheet(
            context,
            title: 'Tidak punya email?',
            paragraphs: const [
              'Giliran memakai email untuk masuk, jadi akunmu aman tanpa '
                  'kata sandi.',
              'Tanpa email, pengurus arisan tetap bisa menambahkan kamu '
                  'sebagai anggota tamu. Iuranmu tetap tercatat di grup.',
            ],
          ),
        ),
      ],
    );
  }
}

/// "Terlalu sering. Coba lagi dalam 12:30" after a `429`.
class const _RetryCountdown({required final ValueNotifier<DateTime?> retryUntil}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: retryUntil,
      builder: (context, until, _) => until == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: AppSpace.s2),
              child: CountdownText(
                prefix: 'Terlalu sering. Coba lagi dalam ',
                until: until,
                onFinished: () => retryUntil.value = null,
              ),
            ),
    );
  }
}

/// "Kirim kode", docked above the keyboard.
class const _SendButton({
  required final ValueNotifier<DateTime?> retryUntil,
  required final VoidCallback onSubmit,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(
      emailOtpRequestControllerProvider.select((s) => s.isLoading),
    );

    return ValueListenableBuilder(
      valueListenable: retryUntil,
      builder: (context, until, _) => AppButton(
        label: 'Kirim kode',
        block: true,
        loading: loading,
        onPressed: until == null ? onSubmit : null,
      ),
    );
  }
}

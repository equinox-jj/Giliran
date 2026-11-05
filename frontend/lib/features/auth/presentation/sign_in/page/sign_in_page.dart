import '../../../../../core/l10n/l10n.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_illustrations.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/otp_purpose.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../shared/widgets/auth_scaffold.dart';
import '../controllers/email_otp_request_controller.dart';

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
      _error.value = context.l10n.widgetEmailFormatError;
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
          _error.value = failure.displayMessage(context.l10n);
        }
      case NetworkFailure() || TimeoutFailure() || ServerFailure() || UnknownFailure():
        showAppToast(
          context,
          failure.displayMessage(context.l10n),
          actionLabel: context.l10n.commonRetry,
          onAction: _submit,
        );
      default:
        _error.value = failure.fieldMessage('email') ?? failure.displayMessage(context.l10n);
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
      // The hero panel sits right under the bar.
      topPadding: context.isCompact ? 0 : AppSpace.s2,
      maxWidth: context.isCompact ? AuthScaffold.formMax : AppSizes.boardMax,
      body: context.isCompact ? form : _WideLayout(form: form),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          _SendButton(retryUntil: _retryUntil, onSubmit: _submit),
          const _LegalNote(),
        ],
      ),
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
          const _HeroIllustration(),
          const SizedBox(height: AppSpace.s6),
        ],
        HeadlineText(context.l10n.authSignInHeadline),
        const SizedBox(height: AppSpace.s2),
        Text(
          context.l10n.authSignInCaption,
          style: t.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpace.s5),
        ValueListenableBuilder(
          valueListenable: error,
          builder: (context, error, _) => EmailField(
            controller: email,
            helper: context.l10n.authSignInHelper,
            errorText: error,
            autofocus: true,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        _RetryCountdown(retryUntil: retryUntil),
        const SizedBox(height: 18),
        AppBanner(
          note: true,
          icon: AppIcons.shieldCheck,
          message: context.l10n.authSignInPrivacyNote,
        ),
      ],
    );
  }
}

/// The `email_slip` illustration on the hero tone, full width (phone only).
class const _HeroIllustration() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: context.colors.hero,
        shape: AppShapes.squircle(AppRadius.xl),
      ),
      child: const Illustration(AppIllustrations.emailSlip, width: 240, height: 140),
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
                prefix: context.l10n.authRateLimitedPrefix,
                until: until,
                showTimeOnSameDay: false,
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
        label: context.l10n.authSendCode,
        block: true,
        loading: loading,
        onPressed: until == null ? onSubmit : null,
      ),
    );
  }
}

/// "Dengan lanjut, kamu setuju dengan Syarat & Kebijakan Privasi." under the
/// button; both links open the privacy page. Stateful to own the link
/// recognizers.
class const _LegalNote() extends StatefulWidget {
  static final _privacyUrl = Uri.parse('https://giliran.monai.my.id/privacy');

  @override
  State<_LegalNote> createState() => _LegalNoteState();
}

class _LegalNoteState() extends State<_LegalNote> {
  late final _terms = TapGestureRecognizer()..onTap = _open;
  late final _privacy = TapGestureRecognizer()..onTap = _open;

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  void _open() => launchUrl(_LegalNote._privacyUrl, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final link = TextStyle(
      color: c.link,
      decoration: TextDecoration.underline,
      decorationColor: c.link,
    );

    return Text.rich(
      TextSpan(
        text: context.l10n.authConsentPrefix,
        children: [
          TextSpan(text: context.l10n.authTerms, style: link, recognizer: _terms),
          const TextSpan(text: ' & '),
          TextSpan(text: context.l10n.authPrivacyPolicy, style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
      style: t.caption.copyWith(color: c.textTertiary),
    );
  }
}

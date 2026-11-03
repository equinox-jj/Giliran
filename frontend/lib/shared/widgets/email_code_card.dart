import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_icon.dart';
import 'illustration.dart';
import 'otp_input.dart';

/// What the [EmailCodeCard] shows (design system 8.35).
enum EmailCodeCardState() {
  /// Waiting for the user to type the code.
  waiting,

  /// Verifying: boxes dim, input disabled, spinner under them.
  checking,

  /// `otp_invalid`: boxes shake, turn bata and clear.
  wrong,

  /// `otp_expired`: `unpaid` colors and "Kirim kode baru".
  expired,

  /// `otp_too_many_attempts`: `rejected` colors and back to the email screen.
  locked,

  /// The code was accepted: `paid` colors with a check.
  success,
}

class const EmailCodeCard({
  super.key,
  required final String emailMasked,
  required final ValueChanged<String> onCompleted,
  final EmailCodeCardState state = EmailCodeCardState.waiting,

  /// Caption under the boxes, such as "Kode salah. Sisa 2 kali coba.".
  /// Announced to screen readers when it changes.
  final String? message,
  final VoidCallback? onChangeEmail,
  final DateTime? resendAvailableAt,
  final VoidCallback? onResend,
  final bool resending = false,

  /// The primary on [EmailCodeCardState.expired] ("Kirim kode baru").
  final VoidCallback? onRequestNew,

  /// The primary on [EmailCodeCardState.locked] (back to the email screen).
  final VoidCallback? onRestart,
  final Widget? pinStep,

  /// "Buka aplikasi email" under the resend row; hidden when null.
  final VoidCallback? onOpenMail,
}) extends StatefulWidget {
  /// How long before "Belum dapat? Cek folder Spam/Promosi" appears.
  static const spamHintDelay = Duration(seconds: 30);

  @override
  State<EmailCodeCard> createState() => _EmailCodeCardState();
}

class _EmailCodeCardState() extends State<EmailCodeCard> {
  @override
  void didUpdateWidget(EmailCodeCard old) {
    super.didUpdateWidget(old);
    final message = widget.message;
    if (message != null && message != old.message) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = widget.state;
    final tone = switch (state) {
      EmailCodeCardState.success => c.paid,
      EmailCodeCardState.expired => c.unpaid,
      EmailCodeCardState.locked => c.rejected,
      _ => null,
    };
    final closed = state == EmailCodeCardState.expired || state == EmailCodeCardState.locked;
    final pinStep = widget.pinStep;

    return AppCard(
      color: tone?.bg,
      child: AnimatedSize(
        duration: AppMotion.emphasis,
        curve: AppMotion.baseCurve,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              emailMasked: widget.emailMasked,
              success: state == EmailCodeCardState.success,
              onChangeEmail: widget.onChangeEmail,
            ),
            const SizedBox(height: AppSpace.s6),
            if (pinStep != null)
              pinStep
            else if (closed)
              _ClosedState(
                state: state,
                message: widget.message,
                onRequestNew: widget.onRequestNew,
                onRestart: widget.onRestart,
                resending: widget.resending,
              )
            else ...[
              OtpInput(
                error: state == EmailCodeCardState.wrong,
                checking: state == EmailCodeCardState.checking || state == EmailCodeCardState.success,
                onCompleted: widget.onCompleted,
              ),
              if (widget.message case final message?) ...[
                const SizedBox(height: AppSpace.s3),
                _Caption(message, error: state == EmailCodeCardState.wrong),
              ],
              if (state != EmailCodeCardState.success) ...[
                const SizedBox(height: AppSpace.s5),
                _ResendRow(
                  until: widget.resendAvailableAt,
                  resending: widget.resending,
                  onResend: widget.onResend,
                ),
                if (widget.onOpenMail case final onOpenMail?) ...[
                  const SizedBox(height: AppSpace.s3),
                  AppButton.secondary(
                    label: 'Buka aplikasi email',
                    icon: AppIcons.envelopeSimple,
                    size: AppButtonSize.small,
                    onPressed: onOpenMail,
                  ),
                ],
                const SizedBox(height: AppSpace.s2),
                const _SpamHint(),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The waiting envelope (or the success check), title and "Dikirim ke … · Ubah".
class const _Header({
  required final String emailMasked,
  required final bool success,
  required final VoidCallback? onChangeEmail,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return Column(
      children: [
        if (success)
          AppIcon(
            AppIcons.checkCircleFill,
            size: 72,
            color: c.paid.fg,
            semanticLabel: 'Kode benar',
          )
        else
          const Illustration(AppIllustrations.emailWaiting, width: 72, height: 72),
        const SizedBox(height: AppSpace.s4),
        Text(
          'Masukkan kode dari email',
          textAlign: TextAlign.center,
          style: t.titleLg.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AppSpace.s1),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Dikirim ke $emailMasked',
              style: t.body.copyWith(color: c.textSecondary),
            ),
            if (onChangeEmail != null)
              AppButton.ghost(
                label: 'Ubah',
                semanticLabel: 'Ubah email',
                size: AppButtonSize.xsmall,
                onPressed: onChangeEmail,
              ),
          ],
        ),
      ],
    );
  }
}

/// Expired or locked: the reason and one primary action.
class const _ClosedState({
  required final EmailCodeCardState state,
  required final String? message,
  required final VoidCallback? onRequestNew,
  required final VoidCallback? onRestart,
  required final bool resending,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final expired = state == EmailCodeCardState.expired;
    final fg = expired ? c.unpaid.fg : c.rejected.fg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message ?? (expired ? 'Kode kedaluwarsa' : 'Terlalu banyak percobaan. Minta kode baru.'),
          textAlign: TextAlign.center,
          style: t.label.copyWith(color: fg),
        ),
        const SizedBox(height: AppSpace.s4),
        if (expired)
          AppButton(
            label: 'Kirim kode baru',
            block: true,
            loading: resending,
            onPressed: onRequestNew,
          )
        else
          AppButton(
            label: 'Minta kode baru',
            block: true,
            onPressed: onRestart,
          ),
      ],
    );
  }
}

class const _Caption(final String text, {required final bool error}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return Text(
      text,
      textAlign: TextAlign.center,
      style: t.caption.copyWith(color: error ? c.rejected.fg : c.textSecondary),
    );
  }
}

/// "Kirim ulang dalam 00:42", then the "Kirim ulang" button once
/// `resend_available_at` has passed.
class const _ResendRow({
  required final DateTime? until,
  required final bool resending,
  required final VoidCallback? onResend,
}) extends StatefulWidget {
  @override
  State<_ResendRow> createState() => _ResendRowState();
}

class _ResendRowState() extends State<_ResendRow> {
  Timer? _timer;

  bool get _waiting => widget.until?.isAfter(DateTime.now()) ?? false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_ResendRow old) {
    super.didUpdateWidget(old);
    if (old.until != widget.until) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    if (!_waiting) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_waiting) timer.cancel();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final until = widget.until;

    if (until != null && _waiting) {
      final left = until.difference(DateTime.now());
      final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
      return Text(
        'Kirim ulang dalam ${left.inMinutes}:$seconds',
        style: t.body.copyWith(
          color: c.textSecondary,
          fontFeatures: AppTextStyles.tabularFigures,
        ),
      );
    }
    return AppButton.ghost(
      label: 'Kirim ulang',
      size: AppButtonSize.small,
      loading: widget.resending,
      onPressed: widget.onResend,
    );
  }
}

/// "Belum dapat? Cek folder Spam/Promosi", shown after
/// [EmailCodeCard.spamHintDelay].
class const _SpamHint() extends StatefulWidget {
  @override
  State<_SpamHint> createState() => _SpamHintState();
}

class _SpamHintState() extends State<_SpamHint> {
  late final Timer _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(
      EmailCodeCard.spamHintDelay,
      () => setState(() => _visible = true),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: AppMotion.quick,
      child: ExcludeSemantics(
        excluding: !_visible,
        child: Text(
          'Belum dapat? Cek folder Spam/Promosi',
          textAlign: TextAlign.center,
          style: t.caption.copyWith(color: c.textTertiary),
        ),
      ),
    );
  }
}

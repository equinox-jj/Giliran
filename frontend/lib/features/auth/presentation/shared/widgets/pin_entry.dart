import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';

/// The S06 layout: a centered headline and caption, the PIN dots, a hint or
/// error strip under them, and the keypad at the bottom (beside them on a
/// short landscape window). Used by S06 and by the new PIN step of S09.
/// Needs a bounded height (`AuthScaffold.pinPad`).
class const PinEntry({
  super.key,
  required final String headline,
  required final PinPadController controller,
  required final ValueChanged<String> onCompleted,
  final String? caption,

  /// Replaces [hint] in the strip under the dots, in `rejected` colors.
  final String? error,

  /// The info strip under the dots, such as the weak PIN advice.
  final String? hint,
  final bool enabled = true,

  /// Verifying the entry; see `PinPad.checking`.
  final bool checking = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PinPad(
    controller: controller,
    error: error != null,
    enabled: enabled,
    checking: checking,
    expand: true,
    onCompleted: onCompleted,
    header: _Heading(headline: headline, caption: caption),
    belowDots: _Strip(error: error, hint: hint),
    footer: const SizedBox(height: AppSpace.s4),
  );
}

/// The current-PIN step of S45 and S46: the S06 layout with "PIN salah"
/// under the dots and "Lupa PIN?" under the pad, or the lock countdown in
/// place of the pad while [lockedUntil] is set (`pin_locked`).
class const CurrentPinEntry({
  super.key,
  required final String headline,
  required final PinPadController controller,
  required final ValueChanged<String> onCompleted,
  required final VoidCallback onForgotPin,
  final String? caption,

  /// "PIN salah" with the attempts left, or another error, under the dots.
  final String? error,
  final bool checking = false,
  final DateTime? lockedUntil,

  /// The lock countdown ran out.
  final VoidCallback? onLockFinished,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final header = _Heading(headline: headline, caption: caption);
    final footer = _ForgotPinLink(onPressed: onForgotPin);
    final until = lockedUntil;

    if (until != null) {
      return PinCountdownLayout(
        header: header,
        countdown: CountdownText.lock(
          until: until,
          caption: 'PIN terkunci sementara. Coba lagi setelah waktu habis.',
          onFinished: onLockFinished,
        ),
        footer: footer,
      );
    }
    return PinPad(
      controller: controller,
      error: error != null,
      checking: checking,
      expand: true,
      onCompleted: onCompleted,
      header: header,
      belowDots: PinErrorLine(message: error),
      footer: footer,
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
      AppButton.link(label: 'Lupa PIN?', size: AppButtonSize.small, onPressed: onPressed),
      const SizedBox(height: AppSpace.s2),
    ],
  );
}

/// "PIN salah. Sisa {n} percobaan." for a wrong current PIN (S45, S46),
/// else null.
String? wrongPinMessage(Failure? failure) {
  if (failure?.apiCode != ApiErrorCode.pinInvalid) return null;
  return switch (failure?.attemptsRemaining) {
    final n? => 'PIN salah. Sisa $n percobaan.',
    null => 'PIN salah.',
  };
}

/// The headline and caption over the dots, with the space around them.
class const _Heading({required final String headline, required final String? caption}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpace.s6),
        HeadlineText(headline, textAlign: TextAlign.center),
        if (caption case final caption?) ...[
          const SizedBox(height: AppSpace.s2),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: c.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpace.s10),
      ],
    );
  }
}

/// The strip under the dots: the error, else the hint, else nothing.
class const _Strip({required final String? error, required final String? hint}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final text = error ?? hint;
    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s6),
      child: SizedBox(
        width: double.infinity,
        child: AppBanner(
          message: text,
          compact: true,
          variant: error == null ? AppBannerVariant.info : AppBannerVariant.error,
          icon: error == null ? AppIcons.info : AppIcons.warningCircle,
        ),
      ),
    );
  }
}

/// The bata "PIN salah" line under the PIN dots (S04, S08), with a
/// `WarningCircle`. Keeps its height when empty so the dots do not jump.
class const PinErrorLine({super.key, required final String? message}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final message = this.message;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: SizedBox(
        height: AppSizes.iconMd,
        child: Semantics(
          liveRegion: true,
          child: message == null
              ? const SizedBox.shrink()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    AppIcon(AppIcons.warningCircle, size: AppSizes.iconSm, color: c.rejected.fg),
                    Text(
                      message,
                      style: t.label.copyWith(color: c.rejected.fg, fontSize: 13),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Stands in for the `PinPad` while the PIN is locked (S04, S08): the
/// [header] at the top, the [countdown] in the middle and the [footer] at the
/// bottom, scrolling when the window is too short for them.
class const PinCountdownLayout({
  super.key,
  required final Widget header,
  required final Widget countdown,
  final Widget? footer,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [header, countdown, footer ?? const SizedBox.shrink()],
        ),
      ),
    ),
  );
}

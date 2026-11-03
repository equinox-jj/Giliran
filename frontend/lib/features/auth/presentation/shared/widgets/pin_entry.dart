import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../shared/widgets/widgets.dart';

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

  final Widget? top,

  /// Space above the headline (under [top] when set).
  final double headingTop = AppSpace.s6,

  /// Space between the caption and the dots.
  final double dotsGap = AppSpace.s10,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PinPad(
    controller: controller,
    error: error != null,
    enabled: enabled,
    checking: checking,
    expand: true,
    onCompleted: onCompleted,
    header: _Heading(
      headline: headline,
      caption: caption,
      top: top,
      headingTop: headingTop,
      dotsGap: dotsGap,
    ),
    belowDots: _Strip(error: error, hint: hint),
    footer: const SizedBox(height: AppSpace.s4),
  );
}

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

  /// See [PinEntry.top].
  final Widget? top,
  final double headingTop = AppSpace.s6,
  final double dotsGap = AppSpace.s10,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final header = _Heading(
      headline: headline,
      caption: caption,
      top: top,
      headingTop: headingTop,
      dotsGap: dotsGap,
    );
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
class const _ForgotPinLink({
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: AppSpace.s4),
      AppButton.link(
        label: 'Lupa PIN?',
        size: AppButtonSize.small,
        onPressed: onPressed,
      ),
      const SizedBox(height: AppSpace.s2),
    ],
  );
}

String? wrongPinMessage(Failure? failure) {
  if (failure?.apiCode != ApiErrorCode.pinInvalid) return null;
  return switch (failure?.attemptsRemaining) {
    final n? => 'PIN salah. Sisa $n percobaan.',
    null => 'PIN salah.',
  };
}

/// The headline and caption over the dots, with the space around them.
class const _Heading({
  required final String headline,
  required final String? caption,
  required final Widget? top,
  required final double headingTop,
  required final double dotsGap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?top,
        SizedBox(height: headingTop),
        HeadlineText(headline, textAlign: TextAlign.center),
        if (caption case final caption?) ...[
          const SizedBox(height: AppSpace.s2),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: c.textSecondary),
          ),
        ],
        SizedBox(height: dotsGap),
      ],
    );
  }
}

/// The strip under the dots: the error, else the hint, else nothing.
class const _Strip({
  required final String? error,
  required final String? hint,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final text = error ?? hint;
    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s6),
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.maxWidth,
          child: AppBanner(
            message: text,
            compact: true,
            variant: error == null ? AppBannerVariant.info : AppBannerVariant.error,
            icon: error == null ? AppIcons.info : AppIcons.warningCircle,
          ),
        ),
      ),
    );
  }
}

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
          children: [
            header,
            countdown,
            footer ?? const SizedBox.shrink(),
          ],
        ),
      ),
    ),
  );
}

import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'pressable.dart';

enum AppButtonVariant() {
  /// The one main action on a screen (`bg.inverse`). Max one per viewport.
  ink,

  /// Alternatives, 1.5 px `border.strong` outline.
  secondary,

  /// Actions inside a tone hero; 8% ink over the tone.
  tonal,

  /// Low emphasis: Batal, Nanti saja, Lewati.
  ghost,

  /// A text action in `text.link`: Ubah, Lupa PIN?.
  link,

  /// Only inside a confirmation dialog.
  destructive,
}

enum AppButtonSize() {
  /// 52 high (44 for tonal and ghost).
  regular,

  /// 44 high.
  small,

  /// 36 high, 13 px label.
  xsmall,
}

/// Tikar pill button.
///
/// Disabled when [onPressed] is null or [disabledReason] is set; the reason is
/// shown in a caption under the button ("Lengkapi info rekening dulu").
class AppButton extends StatelessWidget {
  const new({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.ink,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.block = false,
    this.disabledReason,
    this.semanticLabel,
  });

  const new secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.block = false,
    this.disabledReason,
    this.semanticLabel,
  }) : variant = AppButtonVariant.secondary;

  const new tonal({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.block = false,
    this.disabledReason,
    this.semanticLabel,
  }) : variant = AppButtonVariant.tonal;

  const new ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.block = false,
    this.disabledReason,
    this.semanticLabel,
  }) : variant = AppButtonVariant.ghost;

  const new link({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.block = false,
    this.disabledReason,
    this.semanticLabel,
  }) : variant = AppButtonVariant.link;

  const new destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.block = false,
    this.disabledReason,
    this.semanticLabel,
  }) : variant = AppButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;

  /// Leading icon asset from `AppIcons` (20 px).
  final String? icon;

  /// Trailing icon asset from `AppIcons` (20 px), e.g. the arrow on "Lanjut".
  /// Ignored when [icon] is set.
  final String? trailingIcon;
  final bool loading;

  /// Stretch to the available width.
  final bool block;
  final String? disabledReason;
  final String? semanticLabel;

  bool get _enabled => onPressed != null && disabledReason == null;

  double get _height => switch (size) {
    AppButtonSize.xsmall => AppSizes.buttonHXs,
    AppButtonSize.small => AppSizes.buttonHSm,
    AppButtonSize.regular => switch (variant) {
      AppButtonVariant.tonal || AppButtonVariant.ghost || AppButtonVariant.link => AppSizes.buttonHSm,
      _ => AppSizes.buttonH,
    },
  };

  double get _padding => switch (size) {
    AppButtonSize.regular => AppSpace.s6,
    AppButtonSize.small => 18,
    AppButtonSize.xsmall => 14,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    var (Color? fill, Color fg, BorderSide side) = switch (variant) {
      AppButtonVariant.ink => (c.inverse, c.textOnInverse, BorderSide.none),
      AppButtonVariant.secondary => (
        c.surface,
        c.textPrimary,
        BorderSide(color: c.borderStrong, width: AppStroke.regular),
      ),
      AppButtonVariant.tonal => (
        c.textPrimary.withValues(alpha: 0.08),
        c.textPrimary,
        BorderSide.none,
      ),
      AppButtonVariant.ghost => (null, c.textPrimary, BorderSide.none),
      AppButtonVariant.link => (null, c.link, BorderSide.none),
      AppButtonVariant.destructive => (
        c.dangerFill,
        c.onDanger,
        BorderSide.none,
      ),
    };
    if (!_enabled) {
      fill = variant == AppButtonVariant.ghost || variant == AppButtonVariant.link ? null : c.subtle;
      fg = c.textTertiary;
      side = BorderSide.none;
    }

    final style = (size == AppButtonSize.xsmall ? t.label.copyWith(fontSize: 13) : t.label).copyWith(color: fg);

    final spinner = SizedBox.square(
      dimension: AppSizes.iconSm,
      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
    );

    final text = Text(
      label,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    Widget content;
    if (icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: AppSizes.iconMd,
            child: Center(
              child: loading ? spinner : AppIcon(icon!, size: AppSizes.iconMd, color: fg),
            ),
          ),
          const SizedBox(width: AppSpace.s2),
          Flexible(child: text),
        ],
      );
    } else if (trailingIcon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: text),
          const SizedBox(width: AppSpace.s2),
          SizedBox.square(
            dimension: AppSizes.iconMd,
            child: Center(
              child: loading ? spinner : AppIcon(trailingIcon!, size: AppSizes.iconMd, color: fg),
            ),
          ),
        ],
      );
    } else {
      // No icon: keep the label for width, show the spinner over it.
      content = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: loading ? 0 : 1, child: text),
          if (loading) spinner,
        ],
      );
    }

    final hitInset = ((AppSizes.tapMin - _height) / 2).clamp(0.0, 24.0);

    Widget button = Pressable(
      onTap: _enabled && !loading ? onPressed : null,
      semanticLabel: semanticLabel ?? label,
      hitPadding: EdgeInsets.symmetric(vertical: hitInset),
      child: Container(
        height: _height,
        padding: EdgeInsets.symmetric(horizontal: _padding),
        decoration: ShapeDecoration(
          color: fill,
          shape: StadiumBorder(side: side),
        ),
        alignment: Alignment.center,
        child: ExcludeSemantics(child: content),
      ),
    );

    if (!block) button = IntrinsicWidth(child: button);

    if (disabledReason == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: block ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
      children: [
        button,
        const SizedBox(height: 6),
        Text(
          disabledReason!,
          style: t.caption.copyWith(color: c.textTertiary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

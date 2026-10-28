import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'app_badge.dart';
import 'app_icon.dart';
import 'pressable.dart';

enum CircleIconButtonVariant {
  /// 44 transparent circle with a 1.5 px hairline ring: back, menu, bell.
  outline,

  /// 40 ink circle: the row chevron that opens review.
  ink,

  /// 40 cream circle: the action on the viewer's own (ink) row.
  cream,

  /// 88 ink circle: the Kocok button on the draw stage only.
  draw,
}

/// Circle icon button. Always give it a [semanticLabel] ("Kembali",
/// "Menu grup", "Notifikasi, 3 belum dibaca"). The hit area is at least 48.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.variant = CircleIconButtonVariant.outline,
    this.showDot = false,
  });

  const CircleIconButton.ink({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  }) : variant = CircleIconButtonVariant.ink,
       showDot = false;

  const CircleIconButton.cream({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  }) : variant = CircleIconButtonVariant.cream,
       showDot = false;

  const CircleIconButton.draw({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  }) : variant = CircleIconButtonVariant.draw,
       showDot = false;

  final String icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final CircleIconButtonVariant variant;

  /// 8 px bata dot top-right for unread items.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;

    final (
      double size,
      double iconSize,
      Color? fill,
      Color fg,
      BorderSide side,
    ) = switch (variant) {
      CircleIconButtonVariant.outline => (
        AppSizes.circleButton,
        AppSizes.iconCircleButton,
        null,
        c.textPrimary,
        BorderSide(color: c.hairline, width: AppStroke.regular),
      ),
      CircleIconButtonVariant.ink => (
        AppSizes.circleAction,
        AppSizes.iconMd,
        c.inverse,
        c.textOnInverse,
        BorderSide.none,
      ),
      CircleIconButtonVariant.cream => (
        AppSizes.circleAction,
        AppSizes.iconMd,
        c.textOnInverse,
        c.inverse,
        BorderSide.none,
      ),
      CircleIconButtonVariant.draw => (
        AppSizes.drawButton,
        AppSizes.iconXl,
        c.inverse,
        c.textOnInverse,
        BorderSide.none,
      ),
    };

    final hitInset = ((AppSizes.tapMin - size) / 2).clamp(0.0, 24.0);

    return Pressable(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      shape: const CircleBorder(),
      hitPadding: EdgeInsets.all(hitInset),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: enabled ? fill : (fill == null ? null : c.subtle),
                  shape: CircleBorder(side: side),
                ),
                child: Center(
                  child: AppIcon(
                    icon,
                    size: iconSize,
                    color: enabled ? fg : c.textTertiary,
                  ),
                ),
              ),
            ),
            if (showDot) const Positioned(top: 4, right: 4, child: CountDot()),
          ],
        ),
      ),
    );
  }
}

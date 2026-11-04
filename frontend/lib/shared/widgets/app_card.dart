import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'dashed_border.dart';
import 'pressable.dart';

enum AppCardStyle() {
  /// `bg.surface`, no border.
  filled,

  /// `bg.surface` with a 1.5 px hairline.
  outlined,

  /// Transparent with a dashed `border.strong` ("Buat grup", missing info).
  dashed,
}

/// Card: `radius.lg`, padding 16 (phone) / 24 (tablet), never a shadow.
class const AppCard({
  super.key,
  required final Widget child,
  final AppCardStyle style = AppCardStyle.filled,

  /// Fill override (a group tone).
  final Color? color,
  final EdgeInsets? padding,
  final double radius = AppRadius.lg,
  final VoidCallback? onTap,
  final String? semanticLabel,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = padding ?? EdgeInsets.all(context.isCompact ? AppSpace.s4 : AppSpace.s6);

    Widget card = switch (style) {
      AppCardStyle.dashed => DashedBorder(
        color: c.borderStrong,
        radius: radius,
        child: Padding(padding: pad, child: child),
      ),
      _ => Container(
        padding: pad,
        decoration: ShapeDecoration(
          color: color ?? c.surface,
          shape: AppShapes.squircle(
            radius,
            side: style == AppCardStyle.outlined
                ? BorderSide(color: c.hairline, width: AppStroke.regular)
                : BorderSide.none,
          ),
        ),
        child: child,
      ),
    };

    if (onTap != null) {
      card = Pressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        shape: AppShapes.squircle(radius),
        child: card,
      );
    }
    return card;
  }
}

/// List row: min 64, `radius.md`, `bg.surface`, padding 12/16, a leading 40
/// slot, `title` + `body`/secondary subtitle and a trailing slot. Rows are
/// separated by 8 px gaps, not dividers.
class const AppListRow({
  super.key,
  required final String title,
  final String? subtitle,
  final Widget? leading,
  final Widget? trailing,
  final VoidCallback? onTap,

  /// The viewer's own row: ink fill with cream text.
  final bool inverse = false,

  /// One sentence for screen readers; defaults to title + subtitle.
  final String? semanticLabel,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final fg = inverse ? c.textOnInverse : c.textPrimary;
    final fg2 = inverse ? c.textOnInverse.withValues(alpha: 0.75) : c.textSecondary;

    final row = Container(
      constraints: const BoxConstraints(minHeight: AppSizes.rowH),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s4,
        vertical: AppSpace.s3,
      ),
      decoration: ShapeDecoration(
        color: inverse ? c.inverse : c.surface,
        shape: AppShapes.squircle(AppRadius.md),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpace.s3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: t.title.copyWith(color: fg),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) Text(subtitle!, style: t.body.copyWith(color: fg2)),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.s3),
            trailing!,
          ],
        ],
      ),
    );

    final label = semanticLabel ?? [title, if (subtitle != null) subtitle].join(', ');
    if (onTap == null) {
      return Semantics(container: true, label: label, child: row);
    }
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      shape: AppShapes.squircle(AppRadius.md),
      child: row,
    );
  }
}

/// Hero panel: `radius.xl`, a tone fill (default `bg.hero`), padding 24
/// (64 on tablet), min height 200. Max one per screen. [decoration] is an
/// optional corner doodle, painted at 20% opacity and excluded from
/// semantics.
class const HeroPanel({
  super.key,
  required final Widget child,
  final Color? color,
  final Widget? decoration,
  final EdgeInsets? padding,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.heroMinH),
      decoration: ShapeDecoration(
        color: color ?? c.hero,
        shape: AppShapes.squircle(AppRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (decoration != null)
            Positioned(
              right: -6,
              bottom: -8,
              child: ExcludeSemantics(
                child: Opacity(opacity: 0.2, child: decoration),
              ),
            ),
          Padding(
            padding: padding ?? EdgeInsets.all(context.isCompact ? AppSpace.s6 : AppSpace.s8),
            child: child,
          ),
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';

/// 8 px bata dot with a 2 px page-colored ring, for unread items.
class CountDot extends StatelessWidget {
  const CountDot({super.key, this.ringColor});

  /// Defaults to `bg.page`; pass the surface color when placed on a card.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: c.rejected.fg,
        shape: BoxShape.circle,
        border: Border.all(color: ringColor ?? c.page, width: 2),
      ),
    );
  }
}

/// Count badge: min 20 × 20, ink fill, `micro` digits, "9+" above 9.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.max = 9});

  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Container(
      height: 20,
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: ShapeDecoration(color: c.inverse, shape: AppShapes.pill),
      child: Center(
        widthFactor: 1,
        child: Text(
          count > max ? '$max+' : '$count',
          style: t.micro.copyWith(
            color: c.textOnInverse,
            fontFeatures: AppTextStyles.tabularFigures,
          ),
        ),
      ),
    );
  }
}

/// Label badge: `micro` text in a 20-high pill on `bg.subtle`
/// ("Tamu", "Pengurus", "Kamu").
class LabelBadge extends StatelessWidget {
  const LabelBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
      decoration: ShapeDecoration(color: c.subtle, shape: AppShapes.pill),
      child: Center(
        widthFactor: 1,
        child: Text(label, style: t.micro.copyWith(color: c.textSecondary)),
      ),
    );
  }
}

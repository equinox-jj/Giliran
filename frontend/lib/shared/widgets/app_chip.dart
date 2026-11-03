import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'app_badge.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// Filter chip: 40 high, ink when selected.
class const AppChip({
  super.key,
  required final String label,
  required final bool selected,
  required final VoidCallback? onSelected,

  /// Optional 20 px leading icon asset.
  final String? icon,

  /// Optional count badge after the label (pending proofs).
  final int? count,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = selected ? c.textOnInverse : c.textPrimary;

    return Pressable(
      onTap: onSelected == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onSelected!();
            },
      selected: selected,
      semanticLabel: count == null ? label : '$label, $count',
      hitPadding: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedContainer(
        duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.quick,
        curve: AppMotion.quickCurve,
        height: AppSizes.chipH,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
        decoration: ShapeDecoration(
          color: selected ? c.inverse : (dark ? c.subtle : c.surface),
          shape: StadiumBorder(
            side: selected || dark ? BorderSide.none : BorderSide(color: c.hairline, width: AppStroke.regular),
          ),
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppIcon(icon!, size: AppSizes.iconMd, color: fg),
                const SizedBox(width: AppSpace.s2),
              ],
              Text(label, style: t.label.copyWith(color: fg)),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                selected ? _InvertedCount(count!) : CountBadge(count!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class const _InvertedCount(final int count) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 20,
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: ShapeDecoration(
        color: c.textOnInverse,
        shape: AppShapes.pill,
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          count > 9 ? '9+' : '$count',
          style: AppTextStyles.of(context).micro.copyWith(color: c.inverse),
        ),
      ),
    );
  }
}

/// One tab of [PillTabs].
class const PillTab(final String label, {final String? icon, final int? count});

/// Pill tabs (Pembayaran · Jadwal · Anggota · Aktivitas). Scrolls
/// horizontally on compact; laid out in a wrapping row from medium.
class const PillTabs({
  super.key,
  required final List<PillTab> tabs,
  required final int selectedIndex,
  required final ValueChanged<int> onChanged,
  final EdgeInsets padding = EdgeInsets.zero,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chips = [
      for (var i = 0; i < tabs.length; i++)
        AppChip(
          label: tabs[i].label,
          icon: tabs[i].icon,
          count: tabs[i].count,
          selected: i == selectedIndex,
          onSelected: () => onChanged(i),
        ),
    ];

    if (!context.isCompact) {
      return Padding(
        padding: padding,
        child: Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: chips,
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s2),
            chips[i],
          ],
        ],
      ),
    );
  }
}

/// Segmented control (Periode · Bulan, Aktif · Selesai): a `bg.subtle` track
/// holding pills; the selected pill is `bg.surface` with float elevation.
class const SegmentedPills({
  super.key,
  required final List<String> segments,
  required final int selectedIndex,
  required final ValueChanged<int> onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final duration = AppMotion.reduced(context) ? Duration.zero : AppMotion.base;

    return Container(
      height: AppSizes.tapMin,
      // The vertical inset is each pill's hitPadding, so a segment's tap
      // area is the full 48 track height while the pill stays 40.
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s1),
      decoration: ShapeDecoration(color: c.subtle, shape: AppShapes.pill),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(
              child: Pressable(
                onTap: i == selectedIndex
                    ? () {}
                    : () {
                        HapticFeedback.selectionClick();
                        onChanged(i);
                      },
                selected: i == selectedIndex,
                semanticLabel: segments[i],
                hitPadding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
                scale: false,
                tint: false,
                child: AnimatedContainer(
                  duration: duration,
                  curve: AppMotion.baseCurve,
                  decoration: ShapeDecoration(
                    color: i == selectedIndex ? c.surface : null,
                    shape: AppShapes.pill,
                    shadows: i == selectedIndex ? AppElevation.float(context) : const [],
                  ),
                  alignment: Alignment.center,
                  child: ExcludeSemantics(
                    child: Text(
                      segments[i],
                      style: t.label.copyWith(
                        color: i == selectedIndex ? c.textPrimary : c.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

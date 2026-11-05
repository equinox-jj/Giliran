import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_doodles.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/enums/group_status.dart';
import '../../core/utils/enums/period_type.dart';
import '../../features/group/domain/entities/group_summary.dart';
import 'app_badge.dart';
import 'doodle.dart';
import 'giliran_ring.dart';
import 'pressable.dart';
import 'status_chip.dart';

/// Where a [GroupCard] sits: the Home carousel (260 × 220), the Groups list
/// (full width, 160 high) or a tablet grid cell (sized by the grid).
enum GroupCardLayout() {
  carousel,
  list,
  grid,
}

/// The group card (Tikar §9.10) in the group's tone: initial, cycle or fill
/// ring, name and dues, my status this period, and the "Pengurus" chip and
/// pending dot for organizers.
class const GroupCard({
  super.key,
  required final GroupSummary group,
  required final VoidCallback onTap,
  final GroupCardLayout layout = GroupCardLayout.carousel,
}) extends StatelessWidget {
  static const carouselWidth = 260.0;
  static const carouselHeight = 220.0;
  static const listHeight = 160.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = c.tones[group.toneIndex % c.tones.length];
    final card = Pressable(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      semanticLabel: group.name,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: tone.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: layout == GroupCardLayout.list
              // Draws the list card without the doodle.
              ? Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: _ListBody(group: group, tone: tone),
                )
              : Stack(
                  children: [
                    const PositionedDirectional(
                      end: -AppSpace.s4,
                      bottom: -AppSpace.s4,
                      child: Doodle(AppDoodles.rantang, size: 96, opacity: 0.35),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      child: _CardBody(group: group, accent: tone.accent),
                    ),
                  ],
                ),
        ),
      ),
    );
    return switch (layout) {
      GroupCardLayout.carousel => SizedBox(width: carouselWidth, height: carouselHeight, child: card),
      GroupCardLayout.list => SizedBox(height: listHeight, child: card),
      GroupCardLayout.grid => card,
    };
  }
}

/// The carousel and grid card: initial and badges on top, the title
/// stacked under them.
class const _CardBody({required final GroupSummary group, required final Color accent}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Initial(name: group.name ?? ''),
            const Spacer(),
            _Badges(group: group, accent: accent),
          ],
        ),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.bottomStart,
            child: _Title(group: group, maxLines: 2),
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        _BottomRow(group: group),
      ],
    );
  }
}

/// The Groups list card: the initial (with the pending count), then
/// the "PENGURUS" badge, name, "Rp200.000 / bulan · 10 slot" and my status
/// with a date caption, and the ring at the end.
class const _ListBody({required final GroupSummary group, required final GroupTone tone}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    final total = group.totalSlots ?? 0;
    final isDraft = group.status == GroupStatus.draft;
    final value = isDraft ? (group.filledSlots ?? 0) : (group.currentPeriodNo ?? 0);
    final pending = group.pendingReviewCount ?? 0;
    final unit = group.periodType == PeriodType.weekly ? l10n.periodUnitWeekly : l10n.periodUnitMonthly;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _Initial(name: group.name ?? ''),
            if (pending > 0)
              PositionedDirectional(
                top: -6,
                end: -8,
                child: Semantics(
                  label: l10n.groupCardPendingSemantics(pending),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: ShapeDecoration(color: tone.surface, shape: AppShapes.pill),
                    child: ExcludeSemantics(child: CountBadge(pending)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (group.isManager) ...[
                LabelBadge(l10n.roleManagerBadge.toUpperCase(), onTone: true),
                const SizedBox(height: AppSpace.s1),
              ],
              Text(
                group.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.titleLg.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.groupCardDuesSlots(l10n.amountPerPeriod(Rupiah.format(group.amount ?? 0), unit), total),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.body.copyWith(color: c.textPrimary, fontFeatures: AppTextStyles.tabularFigures),
              ),
              const Spacer(),
              _BottomRow(group: group, withCaption: true),
            ],
          ),
        ),
        const SizedBox(width: 14),
        GiliranRing(
          value: value,
          total: total,
          size: GiliranRingSize.s48,
          color: tone.accent,
          semanticsLabel: isDraft ? l10n.ringFillSemantics(value, total) : l10n.ringCycleSemantics(value, total),
        ),
      ],
    );
  }
}

/// The "Pengurus" chip and the ring with its pending dot.
class const _Badges({required final GroupSummary group, required final Color accent}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = group.totalSlots ?? 0;
    final isDraft = group.status == GroupStatus.draft;
    final value = isDraft ? (group.filledSlots ?? 0) : (group.currentPeriodNo ?? 0);
    final pending = group.pendingReviewCount ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group.isManager) ...[
          LabelBadge(l10n.roleManagerBadge),
          const SizedBox(width: AppSpace.s2),
        ],
        Stack(
          clipBehavior: Clip.none,
          children: [
            GiliranRing(
              value: value,
              total: total,
              size: GiliranRingSize.s48,
              color: accent,
              semanticsLabel: isDraft ? l10n.ringFillSemantics(value, total) : l10n.ringCycleSemantics(value, total),
            ),
            if (pending > 0)
              PositionedDirectional(
                top: 0,
                end: 0,
                child: Semantics(
                  label: l10n.groupCardPendingSemantics(pending),
                  child: const CountDot(),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class const _Initial({required final String name}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: AppSizes.avatarLg - 8,
        height: AppSizes.avatarLg - 8,
        alignment: Alignment.center,
        decoration: ShapeDecoration(color: c.inverse, shape: const CircleBorder()),
        child: Text(initial, style: t.titleLg.copyWith(color: c.textOnInverse)),
      ),
    );
  }
}

class const _Title({required final GroupSummary group, required final int maxLines}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    final unit = group.periodType == PeriodType.weekly ? l10n.periodUnitWeekly : l10n.periodUnitMonthly;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.name ?? '',
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: t.titleLg.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AppSpace.s1),
        Text(
          l10n.amountPerPeriod(Rupiah.format(group.amount ?? 0), unit),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.body.copyWith(color: c.textSecondary, fontFeatures: AppTextStyles.tabularFigures),
        ),
      ],
    );
  }
}

class const _BottomRow({required final GroupSummary group, final bool withCaption = false}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = group.myPaymentStatus;
    if (withCaption) {
      // The list card: my status (or "Persiapan" in setup) and the next date.
      final draft = group.status == GroupStatus.draft;
      final due = group.nextDueDate;
      final draw = group.nextDrawDate;
      final caption = draft
          ? (due == null ? null : l10n.groupCardStartsOn(AppDate.short(due)))
          : (draw == null ? null : l10n.groupCardDrawOn(AppDate.short(draw)));
      final chip = draft
          ? const StatusChip(ChipStatus.preparing)
          : switch (group.status) {
              GroupStatus.completed => LabelBadge(l10n.groupStatusCompleted),
              GroupStatus.closed => LabelBadge(l10n.groupStatusClosed),
              _ when group.iHaveWon ?? false => const StatusChip(ChipStatus.won),
              _ when status != null => StatusChip(ChipStatus.fromPayment(status, overdue: _overdue)),
              _ => null,
            };
      if (chip == null && caption == null) return const SizedBox(height: AppSizes.statusChipH);
      final c = context.colors;
      return Row(
        children: [
          ?chip,
          if (chip != null && caption != null) const SizedBox(width: AppSpace.s2),
          if (caption != null)
            Flexible(
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.of(context).caption.copyWith(color: c.textPrimary),
              ),
            ),
        ],
      );
    }
    final badge = switch (group.status) {
      GroupStatus.draft => l10n.groupStatusDraft,
      GroupStatus.completed => l10n.groupStatusCompleted,
      GroupStatus.closed => l10n.groupStatusClosed,
      _ => null,
    };
    if (badge != null) return LabelBadge(badge);
    if (group.iHaveWon ?? false) {
      return Row(
        children: [
          if (status != null) ...[
            StatusChip(ChipStatus.fromPayment(status)),
            const SizedBox(width: AppSpace.s2),
          ],
          const StatusChip(ChipStatus.won),
        ],
      );
    }
    if (status == null) return const SizedBox(height: AppSizes.statusChipH);
    return StatusChip(ChipStatus.fromPayment(status, overdue: _overdue));
  }

  bool get _overdue {
    final due = group.nextDueDate;
    if (due == null) return false;
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    return due.isBefore(DateTime.utc(now.year, now.month, now.day));
  }
}

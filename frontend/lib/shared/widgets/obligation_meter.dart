import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import 'dashed_border.dart';
import 'headline_text.dart';

/// Obligation Meter (Tikar §9.6): what a past winner still owes. One
/// segment per period after their win: paid (pandan), overdue (bata), then
/// upcoming (dashed). The label reads "Sudah menang P3 · sisa 7 × Rp200.000";
/// with [showOverdue] (the organizer view) an overdue line follows in bata.
class const ObligationMeter({
  super.key,
  required final String name,
  required final int wonPeriodNo,

  /// Periods after the win, so the segment count (`total_slots -
  /// won_period_no`).
  required final int periodsAfterWin,
  required final int remainingCount,
  required final int remainingAmount,
  final int overdueCount = 0,
  final int overdueAmount = 0,
  final bool showOverdue = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final total = math.max(periodsAfterWin, remainingCount);
    final overdue = math.min(overdueCount, remainingCount);
    final paid = total - remainingCount;
    final perPeriod = remainingCount == 0 ? 0 : remainingAmount ~/ remainingCount;
    final label = remainingCount == 0
        ? l10n.obligationDone(wonPeriodNo)
        : l10n.obligationLabel(wonPeriodNo, remainingCount, Rupiah.format(perPeriod));
    return Semantics(
      container: true,
      label: l10n.obligationSemantics(name, wonPeriodNo, remainingCount, overdue),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            HeadlineText(label, style: t.body, color: c.textPrimary),
            const SizedBox(height: AppSpace.s2),
            SizedBox(
              height: 8,
              child: Row(
                spacing: AppSpace.s1,
                children: [
                  // One segment per period, at most 49: a small fixed row.
                  for (var i = 0; i < total; i++)
                    Expanded(
                      child: _Segment(
                        kind: i < paid
                            ? _SegmentKind.paid
                            : i < paid + overdue
                            ? _SegmentKind.overdue
                            : _SegmentKind.upcoming,
                      ),
                    ),
                ],
              ),
            ),
            if (showOverdue && overdue > 0) ...[
              const SizedBox(height: AppSpace.s2),
              Text(
                l10n.obligationOverdue(overdue, Rupiah.format(overdueAmount)),
                style: t.caption.copyWith(color: c.rejected.fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _SegmentKind() {
  paid,
  overdue,
  upcoming,
}

class const _Segment({required final _SegmentKind kind}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return switch (kind) {
      _SegmentKind.paid => DecoratedBox(
        decoration: ShapeDecoration(color: c.paid.fg, shape: const StadiumBorder()),
      ),
      _SegmentKind.overdue => DecoratedBox(
        decoration: ShapeDecoration(color: c.rejected.fg, shape: const StadiumBorder()),
      ),
      _SegmentKind.upcoming => CustomPaint(
        painter: DashedBorderPainter(color: c.borderStrong, radius: AppRadius.full, strokeWidth: 1),
      ),
    };
  }
}

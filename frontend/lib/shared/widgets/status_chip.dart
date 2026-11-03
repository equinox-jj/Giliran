import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/utils/enums/payment_status.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'dashed_border.dart';
import 'tikar_hatch_painter.dart';

/// Statuses a chip can show. Labels are fixed and map 1:1 to API values.
enum ChipStatus(final String label, final String icon) {
  paid('Sudah bayar', AppIcons.checkCircleFill),
  pendingReview('Menunggu cek', AppIcons.hourglassMedium),
  unpaid('Belum bayar', AppIcons.circleDashed),
  rejected('Ditolak', AppIcons.xCircle),
  overdue('Lewat jatuh tempo', AppIcons.warningCircle),
  won('Sudah dapat', AppIcons.scrollFill),

  /// A group still in setup (draft), on the Groups list card.
  preparing('Persiapan', AppIcons.info);

  /// Overdue is derived: unpaid or rejected with `due_date` before today.
  static ChipStatus fromPayment(PaymentStatus status, {bool overdue = false}) {
    if (overdue && (status == PaymentStatus.unpaid || status == PaymentStatus.rejected)) {
      return ChipStatus.overdue;
    }
    return switch (status) {
      PaymentStatus.paid => ChipStatus.paid,
      PaymentStatus.pendingReview => ChipStatus.pendingReview,
      PaymentStatus.unpaid => ChipStatus.unpaid,
      PaymentStatus.rejected => ChipStatus.rejected,
    };
  }

  StatusColors colorsOf(GiliranColors c) => switch (this) {
    ChipStatus.paid => c.paid,
    ChipStatus.pendingReview => c.pending,
    ChipStatus.unpaid => c.unpaid,
    ChipStatus.rejected || ChipStatus.overdue => c.rejected,
    ChipStatus.won => c.won,
    ChipStatus.preparing => c.info,
  };
}

/// Status chip: color + icon + word, 28 high. Pending paints the tikar hatch;
/// unpaid gets a dashed outline; won (kunyit) carries an ink outline.
class const StatusChip(
  final ChipStatus status, {
  super.key,

  /// Overrides the fixed label (e.g. "Menunggu" in tight rows).
  final String? label,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final colors = status.colorsOf(c);
    final text = label ?? status.label;

    Widget chip = Container(
      height: AppSizes.statusChipH,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: ShapeDecoration(
        // Pending: the hatch paints the fill so the lines sit under the label.
        color: status == ChipStatus.pendingReview ? null : colors.bg,
        shape: StadiumBorder(
          side: status == ChipStatus.won ? BorderSide(color: c.ink, width: AppStroke.ink) : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            status.icon,
            size: AppSizes.iconSm,
            color: colors.fg,
          ),
          const SizedBox(width: AppSpace.s1),
          Text(
            text,
            style: t.caption.copyWith(
              color: colors.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (status == ChipStatus.pendingReview) {
      chip = TikarHatch(
        color: colors.fg,
        background: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: chip,
      );
    } else if (status == ChipStatus.unpaid) {
      chip = DashedBorder(
        color: colors.fg.withValues(alpha: 0.6),
        child: chip,
      );
    }

    return Semantics(
      label: text,
      child: ExcludeSemantics(child: chip),
    );
  }
}

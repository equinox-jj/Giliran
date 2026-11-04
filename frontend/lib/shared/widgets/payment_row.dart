import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import '../../core/utils/code_formatter.dart';
import 'circle_icon_button.dart';
import 'dashed_border.dart';
import 'overflow_menu.dart';
import 'pressable.dart';
import 'status_chip.dart';

/// Payment Row (Tikar §9.3): one slot on the Pembayaran board. 72 high, the
/// slot number token, the payer's name, a status line and the status chip.
///
/// [mine] paints the row in ink (`bg.inverse`) and turns the trailing
/// action into a cream upload circle ([onUpload]). Managers get an ink
/// chevron on pending rows ([onReview]) or an overflow menu ([menuItems]).
/// Guests show the dashed slot ring and a "Tamu" micro label; an offline
/// cash mark waiting to sync shows a small dot ([pendingSync]).
class const PaymentRow({
  super.key,
  required final int slotNo,
  required final String name,
  required final ChipStatus status,

  /// "Dibayar Sab, 1 Nov · Tunai", "Upload …", the reject reason or
  /// "Jatuh tempo …".
  required final String subtitle,

  /// Shows [subtitle] in bata (overdue).
  final bool subtitleAlert = false,
  final bool guest = false,
  final bool mine = false,
  final bool pendingSync = false,
  final VoidCallback? onTap,
  final VoidCallback? onReview,
  final VoidCallback? onUpload,
  final List<OverflowMenuItem> menuItems = const [],
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final fg = mine ? c.textOnInverse : c.textPrimary;
    final secondary = mine ? c.textOnInverse.withValues(alpha: 0.72) : c.textSecondary;
    final slot = CodeFormatter.slotNo(slotNo);
    final detail = [
      subtitle,
      if (guest) l10n.badgeGuest,
      if (pendingSync) l10n.paymentSyncPending,
    ].join(', ');

    return Semantics(
      container: true,
      child: Pressable(
        onTap: onTap,
        shape: AppShapes.squircle(AppRadius.lg),
        semanticLabel: l10n.paymentRowSemantics(slot, name, status.label, detail),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.paymentRowH),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s3),
          decoration: ShapeDecoration(
            color: mine ? c.inverse : c.surface,
            shape: AppShapes.squircle(AppRadius.lg),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: _SlotNumber(slot: slot, guest: guest, mine: mine),
              ),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NameLine(name: name, guest: guest, pendingSync: pendingSync, color: fg),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: subtitleAlert && !mine ? c.rejected.fg : secondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              // On narrow rows the chip scales down instead of overflowing.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: ExcludeSemantics(child: StatusChip(status)),
                ),
              ),
              _Trailing(
                name: name,
                onReview: onReview,
                onUpload: onUpload,
                menuItems: menuItems,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class const _SlotNumber({
  required final String slot,
  required final bool guest,
  required final bool mine,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    const size = AppSizes.avatarMd;
    final digits = Center(
      child: Text(
        slot,
        style: t.title.copyWith(
          color: mine ? c.textOnInverse : c.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    if (guest) {
      return SizedBox.square(
        dimension: size,
        child: DashedBorder.circle(color: mine ? c.textOnInverse : c.borderStrong, child: digits),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: mine ? c.textOnInverse.withValues(alpha: 0.12) : c.subtle,
        shape: const CircleBorder(),
      ),
      child: digits,
    );
  }
}

class const _NameLine({
  required final String name,
  required final bool guest,
  required final bool pendingSync,
  required final Color color,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.label.copyWith(color: color),
          ),
        ),
        if (guest) ...[
          const SizedBox(width: AppSpace.s2),
          Text(l10n.badgeGuest.toUpperCase(), style: t.micro.copyWith(color: color.withValues(alpha: 0.72))),
        ],
        if (pendingSync) ...[
          const SizedBox(width: AppSpace.s2),
          Tooltip(
            message: l10n.paymentSyncPending,
            child: Container(
              key: const ValueKey('payment-row-sync-dot'),
              width: 8,
              height: 8,
              decoration: ShapeDecoration(color: c.pending.fg, shape: const CircleBorder()),
            ),
          ),
        ],
      ],
    );
  }
}

class const _Trailing({
  required final String name,
  required final VoidCallback? onReview,
  required final VoidCallback? onUpload,
  required final List<OverflowMenuItem> menuItems,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (onUpload != null) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpace.s2),
        child: CircleIconButton.cream(
          icon: AppIcons.uploadSimple,
          onPressed: onUpload,
          semanticLabel: l10n.paymentUploadSemantics,
        ),
      );
    }
    if (onReview != null) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpace.s2),
        child: CircleIconButton.ink(
          icon: AppIcons.caretRight,
          onPressed: onReview,
          semanticLabel: l10n.paymentReviewSemantics(name),
        ),
      );
    }
    if (menuItems.isNotEmpty) {
      return OverflowMenuButton(items: menuItems, semanticLabel: l10n.paymentActionsSemantics(name));
    }
    return const SizedBox.shrink();
  }
}

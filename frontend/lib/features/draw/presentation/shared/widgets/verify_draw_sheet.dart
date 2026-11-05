import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/draw.dart';

/// Verify the draw: the three steps, the commitment, the revealed
/// seed, the participants and the result, each copyable, and the badge
/// computed on this device ("Cocok ✓" or "Tidak cocok" with "Laporkan").
Future<void> showVerifyDrawSheet(
  BuildContext context, {
  required Draw draw,
  required DrawVerification verification,
  required VoidCallback onReport,
}) => showAppSheet<void>(
  context,
  builder: (context) => _VerifyDrawSheet(draw: draw, verification: verification, onReport: onReport),
);

class const _VerifyDrawSheet({
  required final Draw draw,
  required final DrawVerification verification,
  required final VoidCallback onReport,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final slots = [...?draw.eligibleSlots]..sort((a, b) => (a.slotNo ?? 0).compareTo(b.slotNo ?? 0));
    final winner = draw.winner;
    String slotLine(DrawSlot s) => '${CodeFormatter.slotNo(s.slotNo ?? 0)} ${s.displayName ?? ''}';
    final steps = [l10n.verifyStep1, l10n.verifyStep2, l10n.verifyStep3];
    return AppSheetBody(
      title: l10n.verifyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Badge(matches: verification.matches),
          if (!verification.matches)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.link(label: l10n.verifyReport, onPressed: onReport),
            ),
          const SizedBox(height: AppSpace.s4),
          if (draw.isFixedOrder)
            Text(l10n.verifyFixedOrder, style: t.body.copyWith(color: c.textSecondary))
          else
            for (final (i, step) in steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s2),
                child: Text('${i + 1}. $step', style: t.body.copyWith(color: c.textSecondary)),
              ),
          const SizedBox(height: AppSpace.s4),
          KeyValueList(
            items: [
              if (draw.seedHash case final hash?)
                KeyValueItem(l10n.verifyCommitment, hash, mono: true, long: true, copyable: true),
              if (draw.seed case final seed?)
                KeyValueItem(l10n.verifySeed, seed, mono: true, long: true, copyable: true),
              KeyValueItem(l10n.verifyParticipants, [for (final s in slots) slotLine(s)].join('\n'), long: true),
              if (winner != null) KeyValueItem(l10n.verifyResult, slotLine(winner)),
            ],
          ),
        ],
      ),
    );
  }
}

class const _Badge({required final bool matches}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final colors = matches ? c.paid : c.rejected;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: colors.bg, shape: AppShapes.squircle(AppRadius.md)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Row(
            children: [
              AppIcon(matches ? AppIcons.sealCheckFill : AppIcons.xCircleFill, color: colors.fg),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Text(
                  matches ? l10n.verifyMatch : l10n.verifyMismatch,
                  style: t.label.copyWith(color: colors.fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

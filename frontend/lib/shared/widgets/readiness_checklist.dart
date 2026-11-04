import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_icon.dart';

/// One row of a [ReadinessChecklist].
final class const ReadinessRow({
  required final String title,
  final String? caption,
  required final bool done,

  /// The server just named this item (a `409` from `POST /start`).
  final bool highlighted = false,
  final String? actionLabel,
  final VoidCallback? onAction,
});

/// Readiness checklist (Tikar §8.29) for Start group (S18): turns the
/// `POST /start` conflicts into a visible list before the user tries. Done
/// rows show a filled check in paid colors; missing ones a dashed circle
/// and their fix action.
class const ReadinessChecklist({super.key, required final List<ReadinessRow> rows}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      style: AppCardStyle.outlined,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // At most three rows: a small fixed group.
        children: [for (final row in rows) _Row(row: row)],
      ),
    );
  }
}

class const _Row({required final ReadinessRow row}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final colors = row.done ? c.paid : (row.highlighted ? c.rejected : c.unpaid);
    final action = row.actionLabel;
    return Semantics(
      container: true,
      label: '${row.title}, ${row.done ? l10n.readinessDone : l10n.readinessMissing}',
      child: Container(
        color: row.highlighted && !row.done ? c.rejected.bg : null,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s3),
        child: Row(
          children: [
            ExcludeSemantics(
              child: AppIcon(row.done ? AppIcons.checkCircleFill : AppIcons.circleDashed, size: 24, color: colors.fg),
            ),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.title, style: t.label.copyWith(color: c.textPrimary)),
                    if (row.caption case final caption?)
                      Text(caption, style: t.caption.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
            ),
            if (!row.done && action != null) ...[
              const SizedBox(width: AppSpace.s2),
              AppButton.secondary(label: action, size: AppButtonSize.xsmall, onPressed: row.onAction),
            ],
          ],
        ),
      ),
    );
  }
}

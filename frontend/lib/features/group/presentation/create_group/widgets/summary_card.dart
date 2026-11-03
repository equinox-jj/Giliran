import 'package:material_ui/material_ui.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';

/// The live S13 summary pinned above "Lanjut": "Total per periode" on the
/// left and the pot (dues × slots) on the right, on `bg.subtle`.
class const SummaryCard({super.key, required final int potAmount}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s4),
        decoration: ShapeDecoration(color: c.subtle, shape: AppShapes.squircle(AppRadius.md)),
        child: Row(
          children: [
            Expanded(
              child: Text(context.l10n.createGroupTotalLabel, style: t.body.copyWith(color: c.textPrimary)),
            ),
            const SizedBox(width: AppSpace.s3),
            Text(
              Rupiah.format(potAmount),
              style: t.titleLg.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                fontFeatures: AppTextStyles.tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

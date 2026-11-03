import 'package:material_ui/material_ui.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/utils/enums/group_status.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/group.dart';

/// The group detail headline: the period and who paid (active), slots
/// filled (draft), or finished / closed.
class const GroupHeadline({super.key, required final GroupDetail group}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = group.totalSlots ?? 0;
    final filled = group.filledSlots ?? 0;
    final text = switch (group.status) {
      GroupStatus.draft when filled >= total => l10n.groupHeadlineDraftFull(filled, total),
      GroupStatus.draft => l10n.groupHeadlineDraft(filled, total, total - filled),
      GroupStatus.completed => l10n.groupHeadlineCompleted,
      GroupStatus.closed => l10n.groupHeadlineClosed,
      _ => l10n.groupHeadlineActive(group.currentPeriodNo ?? 1, total, group.paidCount ?? 0),
    };
    return HeadlineText(text);
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';

/// The four group detail tabs, in order, with their `?tab=` values.
enum DetailTab(final String query) {
  payments('pembayaran'),
  schedule('jadwal'),
  members('anggota'),
  activity('aktivitas');

  static DetailTab fromQuery(String? value) =>
      DetailTab.values.where((t) => t.query == value).firstOrNull ?? DetailTab.payments;
}

/// Pill tabs Pembayaran · Jadwal · Anggota · Aktivitas over the selected
/// tab's body. Each body is filled by its own feature (payments 4.2,
/// schedule 6.1, members 3.5, activity 6.2); until then it is a placeholder.
class const DetailTabs({
  super.key,
  required final DetailTab selected,
  required final ValueChanged<DetailTab> onChanged,

  /// Count badge on Pembayaran (managers with proofs to review).
  final int? pendingCount,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (selected) {
      DetailTab.payments => l10n.tabPayments,
      DetailTab.schedule => l10n.tabSchedule,
      DetailTab.members => l10n.tabMembers,
      DetailTab.activity => l10n.tabActivity,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PillTabs(
          tabs: [
            PillTab(l10n.tabPayments, count: pendingCount),
            PillTab(l10n.tabSchedule),
            PillTab(l10n.tabMembers),
            PillTab(l10n.tabActivity),
          ],
          selectedIndex: selected.index,
          onChanged: (i) => onChanged(DetailTab.values[i]),
        ),
        const SizedBox(height: AppSpace.s4),
        EmptyState(compact: true, title: label, message: l10n.comingSoon),
      ],
    );
  }
}

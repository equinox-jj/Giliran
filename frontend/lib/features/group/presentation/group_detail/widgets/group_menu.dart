import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/usecases/group_menu_actions_usecase.dart';

/// The group overflow menu (Tikar §10.3) for the [actions] the role allows.
class const GroupMenu({
  super.key,
  required final List<GroupMenuAction> actions,
  required final ValueChanged<GroupMenuAction> onSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OverflowMenuButton(
      items: [
        for (final a in actions)
          OverflowMenuItem(
            label: switch (a) {
              GroupMenuAction.share => l10n.menuShare,
              GroupMenuAction.leave => l10n.menuLeave,
              GroupMenuAction.edit => l10n.menuEdit,
              GroupMenuAction.paymentInfo => l10n.menuPaymentInfo,
              GroupMenuAction.invite => l10n.menuInvite,
              GroupMenuAction.reminders => l10n.menuReminders,
              GroupMenuAction.close => l10n.menuClose,
            },
            icon: switch (a) {
              GroupMenuAction.share => AppIcons.shareNetwork,
              GroupMenuAction.leave => AppIcons.signOut,
              GroupMenuAction.edit => AppIcons.pencilSimple,
              GroupMenuAction.paymentInfo => AppIcons.bank,
              GroupMenuAction.invite => AppIcons.userPlus,
              GroupMenuAction.reminders => AppIcons.bellRinging,
              GroupMenuAction.close => AppIcons.trash,
            },
            destructive: a == GroupMenuAction.close,
            onSelected: () => onSelected(a),
          ),
      ],
    );
  }
}

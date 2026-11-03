import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/enums/group_status.dart';
import '../../../../core/utils/enums/member_role.dart';

part 'group_menu_actions_usecase.g.dart';

/// Items of the group overflow menu (Tikar §10.3).
enum GroupMenuAction() {
  share,
  leave,
  edit,
  paymentInfo,
  invite,
  reminders,
  close,
}

/// The group menu by role (Tikar §10.3): members get Bagikan and Minta
/// keluar; the organizer gets Edit grup, Info rekening, Undang, Pengingat
/// and Tutup grup; a co-organizer the same without Tutup grup (payment info
/// stays read-only for them). A closed group offers only Bagikan; managers
/// can't close it twice.
///
/// Pure and synchronous, so it does not go through `UseCase`.
class const GroupMenuActionsUseCase() {
  List<GroupMenuAction> call(({MemberRole? role, GroupStatus? status}) params) {
    if (params.status == GroupStatus.closed) return const [GroupMenuAction.share];
    return switch (params.role) {
      MemberRole.organizer => [
        GroupMenuAction.edit,
        GroupMenuAction.paymentInfo,
        GroupMenuAction.invite,
        GroupMenuAction.reminders,
        GroupMenuAction.close,
      ],
      MemberRole.coOrganizer => const [
        GroupMenuAction.edit,
        GroupMenuAction.paymentInfo,
        GroupMenuAction.invite,
        GroupMenuAction.reminders,
      ],
      _ => const [GroupMenuAction.share, GroupMenuAction.leave],
    };
  }
}

@Riverpod(keepAlive: true)
GroupMenuActionsUseCase groupMenuActionsUseCase(Ref ref) => const GroupMenuActionsUseCase();

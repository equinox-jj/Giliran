import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/features/group/domain/usecases/group_menu_actions_usecase.dart';

void main() {
  final cases = <String, (MemberRole, GroupStatus, List<GroupMenuAction>)>{
    'member': (MemberRole.member, GroupStatus.active, [GroupMenuAction.share, GroupMenuAction.leave]),
    'organizer': (
      MemberRole.organizer,
      GroupStatus.active,
      [
        GroupMenuAction.edit,
        GroupMenuAction.paymentInfo,
        GroupMenuAction.invite,
        GroupMenuAction.reminders,
        GroupMenuAction.close,
      ],
    ),
    'co-organizer cannot close': (
      MemberRole.coOrganizer,
      GroupStatus.active,
      [GroupMenuAction.edit, GroupMenuAction.paymentInfo, GroupMenuAction.invite, GroupMenuAction.reminders],
    ),
    'a closed group only shares': (MemberRole.organizer, GroupStatus.closed, [GroupMenuAction.share]),
  };
  for (final MapEntry(key: label, value: (role, status, expected)) in cases.entries) {
    test(label, () {
      // Act
      final actions = const GroupMenuActionsUseCase()((role: role, status: status));

      // Assert
      expect(actions, expected);
    });
  }
}

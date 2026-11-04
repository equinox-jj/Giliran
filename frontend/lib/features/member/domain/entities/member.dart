import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/member_role.dart';
import '../../../../core/utils/enums/member_status.dart';
import '../../../group/domain/entities/group.dart';

part 'member.freezed.dart';

/// A member or guest of a group, holding one slot.
@freezed
abstract class const Member._() with _$Member {
  const factory({
    String? id,
    String? groupId,

    /// The member's account; `null` for guests.
    UserSummary? user,
    String? displayName,
    bool? isGuest,

    /// Sent to organizers and co-organizers only.
    String? guestPhone,
    MemberRole? role,
    MemberStatus? status,
    String? slotId,
    int? slotNo,
    int? fixedOrderPosition,
    bool? hasWon,
    int? wonPeriodNo,
    DateTime? joinedAt,
  }) = _Member;

  String? get avatarUrl => user?.avatarUrl;

  bool get isManager => role == MemberRole.organizer || role == MemberRole.coOrganizer;
}

/// The compact member inside a leave request, transfer or obligation.
@freezed
abstract class MemberRef with _$MemberRef {
  const factory({
    String? id,
    String? displayName,
    String? avatarUrl,
    bool? isGuest,
    int? slotNo,
  }) = _MemberRef;
}

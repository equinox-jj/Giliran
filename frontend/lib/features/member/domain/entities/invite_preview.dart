import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/group_status.dart';
import '../../../../core/utils/enums/period_type.dart';
import '../../../group/domain/entities/group.dart';

part 'invite_preview.freezed.dart';

/// What Join preview (S25) shows before the user joins.
@freezed
abstract class InvitePreview with _$InvitePreview {
  const factory({
    String? groupId,
    String? groupName,
    UserSummary? organizer,
    int? amount,
    PeriodType? periodType,
    int? totalSlots,
    int? filledSlots,

    /// First due date, a Jakarta business date at UTC midnight.
    DateTime? startDate,
    GroupStatus? status,
    bool? canJoin,
    bool? alreadyMember,
  }) = _InvitePreview;
}

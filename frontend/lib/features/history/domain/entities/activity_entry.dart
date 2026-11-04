import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../group/domain/entities/group.dart';
import '../../../member/domain/entities/member.dart';

part 'activity_entry.freezed.dart';

/// One append-only activity log entry (BR-09, FR-TRN-02): who did what to
/// which entity, with the changed fields before and after. A null [actor]
/// is a system action.
@freezed
abstract class ActivityEntry with _$ActivityEntry {
  const factory({
    String? id,
    String? groupId,
    String? action,
    String? entityType,
    String? entityId,
    UserSummary? actor,

    /// The member the entry is about (a member, a payment's payer or a
    /// payout's winner); null for group and period entries.
    MemberRef? subject,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    DateTime? createdAt,
  }) = _ActivityEntry;
}

/// Where the next page of a group's activity log starts.
class const ActivityCursor({final String? nextCursor, final bool hasMore = false});

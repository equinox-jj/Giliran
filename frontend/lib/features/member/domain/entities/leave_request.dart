import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/leave_request_status.dart';
import '../../../group/domain/entities/group.dart';
import 'member.dart';

part 'leave_request.freezed.dart';

/// A member's request to leave a group (S30, S31).
@freezed
abstract class LeaveRequest with _$LeaveRequest {
  const factory({
    String? id,
    MemberRef? member,
    String? reason,
    LeaveRequestStatus? status,
    UserSummary? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
  }) = _LeaveRequest;
}

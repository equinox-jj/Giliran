import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/transfer_status.dart';
import '../../../group/domain/entities/group.dart';
import 'member.dart';

part 'ownership_transfer.freezed.dart';

/// An offer of the organizer role to another member.
@freezed
abstract class OwnershipTransfer with _$OwnershipTransfer {
  const factory({
    String? id,
    UserSummary? fromUser,
    MemberRef? toMember,
    TransferStatus? status,
    DateTime? expiresAt,
    DateTime? respondedAt,
    DateTime? createdAt,
  }) = _OwnershipTransfer;
}

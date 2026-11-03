import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/enums/draw_method.dart';
import '../../../../core/utils/enums/group_status.dart';
import '../../../../core/utils/enums/member_role.dart';
import '../../../../core/utils/enums/payment_status.dart';
import '../../../../core/utils/enums/period_type.dart';

part 'group.freezed.dart';

/// A group as the detail, edit and payment-info screens see it: the API
/// `Group`, plus the current-period numbers the cache keeps from the last
/// `GroupSummary` (null until the list has been fetched).
@freezed
abstract class const GroupDetail._() with _$GroupDetail {
  const factory({
    String? id,
    String? name,
    int? amount,
    int? potAmount,
    PeriodType? periodType,
    int? totalSlots,
    int? filledSlots,
    DrawMethod? drawMethod,

    /// First due date, a Jakarta business date at UTC midnight.
    DateTime? startDate,
    int? reminderDaysBefore,
    GroupStatus? status,
    UserSummary? organizer,
    MemberRole? myRole,
    String? myMemberId,

    /// Organizers and co-organizers only.
    Invite? invite,
    PaymentInfo? paymentInfo,
    String? currentPeriodId,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? closedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? currentPeriodNo,
    DateTime? nextDueDate,
    DateTime? nextDrawDate,
    PaymentStatus? myPaymentStatus,
    int? paidCount,
    int? pendingReviewCount,
    bool? iHaveWon,
  }) = _GroupDetail;

  /// Index into `GiliranColors.tones`, stable per group.
  int get toneIndex => GiliranColors.toneIndexFor(id ?? '');

  bool get isManager => myRole == MemberRole.organizer || myRole == MemberRole.coOrganizer;
}

/// A user shown by name and avatar, such as the organizer.
@freezed
abstract class UserSummary with _$UserSummary {
  const factory({String? id, String? name, String? avatarUrl}) = _UserSummary;
}

/// The group's invite code and link.
@freezed
abstract class Invite with _$Invite {
  const factory({String? code, String? url}) = _Invite;
}

/// Where members pay their dues: the organizer's account and QRIS.
@freezed
abstract class const PaymentInfo._() with _$PaymentInfo {
  const factory({
    String? bankName,
    String? accountNumber,
    String? accountHolder,

    /// Short-lived signed URL, only on a fresh server response; cached
    /// groups know just [hasQris].
    String? qrisImageUrl,
    String? qrisMerchantName,
    @Default(false) bool hasQris,
  }) = _PaymentInfo;

  bool get hasBankAccount => (accountNumber ?? '').isNotEmpty;
}

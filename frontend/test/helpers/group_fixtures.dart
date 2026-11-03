import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/core/utils/enums/period_type.dart';
import 'package:giliran/features/group/domain/entities/group_summary.dart';

/// An active monthly group where I am a member who has paid, due on
/// [due]; override what a test needs.
GroupSummary summary(
  String id, {
  String? name,
  GroupStatus status = GroupStatus.active,
  MemberRole role = MemberRole.member,
  PaymentStatus? payment = PaymentStatus.paid,
  DateTime? due,
  DateTime? draw,
  int? pending,
}) => GroupSummary(
  id: id,
  name: name ?? 'Arisan $id',
  amount: 200000,
  periodType: PeriodType.monthly,
  status: status,
  myRole: role,
  totalSlots: 10,
  filledSlots: 10,
  currentPeriodNo: 3,
  nextDueDate: due,
  nextDrawDate: draw ?? due,
  myPaymentStatus: payment,
  paidCount: 4,
  pendingReviewCount: pending,
  iHaveWon: false,
);

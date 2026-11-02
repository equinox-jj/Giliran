import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:giliran/core/database/app_database.dart';

AppDatabase openTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

GroupsCompanion groupRow(String id, {String name = 'Arisan RT'}) =>
    GroupsCompanion.insert(
      id: id,
      name: name,
      amount: 200000,
      periodType: 'monthly',
      totalSlots: 10,
      filledSlots: 8,
      status: 'active',
      myRole: 'organizer',
    );

MembersCompanion memberRow(String id, String groupId, int slotNo) =>
    MembersCompanion.insert(
      id: id,
      groupId: groupId,
      displayName: 'Anggota $slotNo',
      isGuest: false,
      role: 'member',
      status: 'active',
      slotId: 'slot-$slotNo',
      slotNo: slotNo,
      hasWon: false,
      joinedAt: DateTime.utc(2026, 10, 1),
    );

PeriodsCompanion periodRow(String id, String groupId, int periodNo) =>
    PeriodsCompanion.insert(
      id: id,
      groupId: groupId,
      periodNo: periodNo,
      dueDate: '2026-11-0$periodNo',
      drawDate: '2026-11-0$periodNo',
      status: 'open',
    );

PaymentsCompanion paymentRow(
  String id,
  String groupId,
  String periodId,
  int slotNo, {
  String status = 'unpaid',
}) => PaymentsCompanion.insert(
  id: id,
  groupId: groupId,
  periodId: periodId,
  memberId: 'm-$slotNo',
  memberDisplayName: 'Anggota $slotNo',
  memberIsGuest: false,
  memberSlotNo: slotNo,
  amount: 200000,
  status: status,
  updatedAt: DateTime.utc(2026, 11, 1),
);

PayoutsCompanion payoutRow(String id, String groupId, String periodId) =>
    PayoutsCompanion.insert(
      id: id,
      groupId: groupId,
      periodId: periodId,
      winnerMemberId: 'm-1',
      winnerDisplayName: 'Anggota 1',
      winnerSlotNo: 1,
      amount: 2000000,
      recordedById: 'u-1',
      recordedByName: 'Bu Sari',
      recordedAt: DateTime.utc(2026, 11, 5),
    );

ActivityLogsCompanion activityRow(
  String id,
  String groupId,
  DateTime createdAt, {
  Map<String, Object?>? after,
}) => ActivityLogsCompanion.insert(
  id: id,
  groupId: groupId,
  action: 'payment.approved',
  entityType: 'payment',
  createdAt: createdAt,
  after: Value(after),
);

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/database/app_database.dart';

import 'fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.groupsDao.upsertAll([groupRow('g1')]);
  });
  tearDown(() => db.close());

  group('MembersDao', () {
    test('replaceForGroup replaces members in slot order', () async {
      // Arrange
      await db.membersDao.replaceForGroup('g1', [memberRow('old', 'g1', 5)]);

      // Act
      await db.membersDao.replaceForGroup('g1', [
        memberRow('m2', 'g1', 2),
        memberRow('m1', 'g1', 1),
      ]);

      // Assert
      final members = await db.membersDao.watchByGroup('g1').first;
      expect(members.map((m) => m.id), ['m1', 'm2']);
    });
  });

  group('PeriodsDao', () {
    test('upsertAll updates an existing period', () async {
      // Arrange
      await db.periodsDao.upsertAll([periodRow('p1', 'g1', 1)]);

      // Act
      await db.periodsDao.upsertAll([
        periodRow('p1', 'g1', 1).copyWith(
          status: const Value('drawn'),
          winnerDisplayName: const Value('Anggota 3'),
        ),
        periodRow('p2', 'g1', 2),
      ]);

      // Assert
      final periods = await db.periodsDao.watchByGroup('g1').first;
      expect(periods.map((p) => p.periodNo), [1, 2]);
      expect(periods.first.status, 'drawn');
      expect(periods.first.winnerDisplayName, 'Anggota 3');
    });
  });

  group('PayoutsDao', () {
    test('upsert stores one payout per period', () async {
      // Arrange
      await db.payoutsDao.upsert(payoutRow('po1', 'g1', 'p1'));

      // Act
      await db.payoutsDao.upsert(
        payoutRow('po1', 'g1', 'p1').copyWith(
          confirmedAt: Value(DateTime.utc(2026, 11, 6)),
        ),
      );

      // Assert
      final payout = await db.payoutsDao.watchByPeriod('p1').first;
      expect(payout?.id, 'po1');
      expect(payout?.confirmedAt, isNotNull);
    });
  });
}

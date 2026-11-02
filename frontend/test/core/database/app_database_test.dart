import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/database/app_database.dart';

import 'fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('deleting a group cascades to its cached children', () async {
    // Arrange
    await db.groupsDao.upsertAll([groupRow('g1')]);
    await db.membersDao.replaceForGroup('g1', [memberRow('m1', 'g1', 1)]);
    await db.periodsDao.upsertAll([periodRow('p1', 'g1', 1)]);
    await db.paymentsDao.replaceForPeriod('p1', [
      paymentRow('pay1', 'g1', 'p1', 1),
    ]);
    await db.payoutsDao.upsert(payoutRow('po1', 'g1', 'p1'));
    await db.activityLogsDao.upsertAll('g1', [
      activityRow('1', 'g1', DateTime.utc(2026, 11, 1)),
    ]);

    // Act
    await db.groupsDao.deleteById('g1');

    // Assert
    expect(await db.select(db.members).get(), isEmpty);
    expect(await db.select(db.periods).get(), isEmpty);
    expect(await db.select(db.payments).get(), isEmpty);
    expect(await db.select(db.payouts).get(), isEmpty);
    expect(await db.select(db.activityLogs).get(), isEmpty);
  });

  test('clearAll empties every table', () async {
    // Arrange
    await db.groupsDao.upsertAll([groupRow('g1'), groupRow('g2')]);
    await db.membersDao.replaceForGroup('g1', [memberRow('m1', 'g1', 1)]);
    await db.paymentsDao.replaceForPeriod('p1', [
      paymentRow('pay1', 'g1', 'p1', 1),
    ]);
    await db.paymentsDao.markPendingCash(
      'pay1',
      idempotencyKey: 'key-12345678',
      paidAt: DateTime.utc(2026, 11, 2),
    );

    // Act
    await db.clearAll();

    // Assert
    for (final table in db.allTables) {
      expect(
        await db.select(table).get(),
        isEmpty,
        reason: table.actualTableName,
      );
    }
  });

  test('rejects a child row whose group is not cached', () async {
    // Arrange
    final orphan = memberRow('m1', 'missing', 1);

    // Act
    final insert = db.into(db.members).insert(orphan);

    // Assert
    await expectLater(insert, throwsA(anything));
  });
}

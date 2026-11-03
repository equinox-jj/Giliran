import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/database/app_database.dart';

import 'fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('upsertAll stores groups and stamps syncedAt', () async {
    // Arrange
    final rows = [groupRow('g1', name: 'B'), groupRow('g2', name: 'A')];

    // Act
    await db.groupsDao.upsertAll(rows);

    // Assert
    final groups = await db.groupsDao.watchAll().first;
    expect(groups.map((g) => g.id), ['g2', 'g1']);
    expect(groups.every((g) => g.syncedAt != null && !g.pendingSync), isTrue);
  });

  test('a summary upsert keeps detail-only columns', () async {
    // Arrange
    await db.groupsDao.upsertAll([
      groupRow('g1').copyWith(
        bankName: const Value('BCA'),
        potAmount: const Value(2000000),
      ),
    ]);

    // Act
    await db.groupsDao.upsertAll([
      groupRow('g1').copyWith(paidCount: const Value(3)),
    ]);

    // Assert
    final group = await db.groupsDao.getById('g1');
    expect(group?.bankName, 'BCA');
    expect(group?.potAmount, 2000000);
    expect(group?.paidCount, 3);
  });

  test('replaceAll drops groups the server no longer returns', () async {
    // Arrange
    await db.groupsDao.upsertAll([groupRow('g1'), groupRow('g2')]);

    // Act
    await db.groupsDao.replaceAll([groupRow('g2')]);

    // Assert
    final groups = await db.groupsDao.watchAll().first;
    expect(groups.map((g) => g.id), ['g2']);
  });

  test('stores instants as UTC with milliseconds', () async {
    // Arrange
    final startedAt = DateTime.utc(2026, 11, 2, 3, 4, 5, 678);

    // Act
    await db.groupsDao.upsertAll([
      groupRow('g1').copyWith(startedAt: Value(startedAt)),
    ]);

    // Assert
    final group = await db.groupsDao.getById('g1');
    expect(group?.startedAt?.toUtc(), startedAt);
  });

  test('watchByStatuses filters by status, soonest due first', () async {
    // Arrange
    await db.groupsDao.upsertAll([
      groupRow('late').copyWith(nextDueDate: const Value('2026-12-01')),
      groupRow('none'),
      groupRow('soon').copyWith(nextDueDate: const Value('2026-11-10')),
      groupRow('done').copyWith(status: const Value('completed')),
    ]);

    // Act
    final groups = await db.groupsDao.watchByStatuses({'draft', 'active'}).first;

    // Assert
    expect(groups.map((g) => g.id), ['soon', 'late', 'none']);
  });

  test('replaceWhere only drops stale groups with the given statuses', () async {
    // Arrange
    await db.groupsDao.upsertAll([
      groupRow('stale'),
      groupRow('done').copyWith(status: const Value('closed')),
    ]);

    // Act
    await db.groupsDao.replaceWhere([groupRow('fresh')], {'draft', 'active'});

    // Assert
    final groups = await db.groupsDao.watchAll().first;
    expect(groups.map((g) => g.id), unorderedEquals(['fresh', 'done']));
  });
}

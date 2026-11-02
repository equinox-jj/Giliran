import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/database/app_database.dart';
import 'package:giliran/core/database/daos/activity_logs_dao.dart';

import 'fixtures.dart';

void main() {
  late AppDatabase db;
  final base = DateTime.utc(2026, 11, 1);

  setUp(() async {
    db = openTestDatabase();
    await db.groupsDao.upsertAll([groupRow('g1')]);
  });
  tearDown(() => db.close());

  test('keeps only the latest entries per group', () async {
    // Arrange
    final rows = [
      for (var i = 0; i < ActivityLogsDao.maxPerGroup + 5; i++)
        activityRow('$i', 'g1', base.add(Duration(minutes: i))),
    ];

    // Act
    await db.activityLogsDao.upsertAll('g1', rows);

    // Assert
    final all = await db.select(db.activityLogs).get();
    expect(all, hasLength(ActivityLogsDao.maxPerGroup));
    expect(all.map((a) => a.id), isNot(contains('0')));
  });

  test('pageBefore returns older entries newest first', () async {
    // Arrange
    await db.activityLogsDao.upsertAll('g1', [
      for (var i = 0; i < 5; i++)
        activityRow('$i', 'g1', base.add(Duration(minutes: i))),
    ]);
    final firstPage = await db.activityLogsDao
        .watchByGroup('g1', limit: 2)
        .first;

    // Act
    final next = await db.activityLogsDao.pageBefore(
      'g1',
      before: firstPage.last,
      limit: 2,
    );

    // Assert
    expect(firstPage.map((a) => a.id), ['4', '3']);
    expect(next.map((a) => a.id), ['2', '1']);
  });

  test('round-trips before/after JSON', () async {
    // Arrange
    final after = {'status': 'paid', 'paid_count': 7};

    // Act
    await db.activityLogsDao.upsertAll('g1', [
      activityRow('1', 'g1', base, after: after),
    ]);

    // Assert
    final entry = (await db.activityLogsDao.watchByGroup('g1').first).single;
    expect(entry.after, after);
    expect(entry.before, isNull);
  });
}

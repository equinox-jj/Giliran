import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/database/app_database.dart';
import 'package:giliran/core/database/daos/notifications_dao.dart';

import 'fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('watchAll lists newest first with the cached group name', () async {
    // Arrange
    await db.groupsDao.upsertAll([groupRow('g1', name: 'Arisan RT 05')]);
    await db.notificationsDao.insertIfAbsent(notificationRow('n1', DateTime.utc(2026, 11, 1)));
    await db.notificationsDao.insertIfAbsent(notificationRow('n2', DateTime.utc(2026, 11, 2), groupId: 'unknown'));

    // Act
    final rows = await db.notificationsDao.watchAll().first;

    // Assert
    expect(rows.map((r) => r.row.id), ['n2', 'n1']);
    expect(rows.last.groupName, 'Arisan RT 05');
    expect(rows.first.groupName, isNull);
  });

  test('a message stored twice is kept once and keeps its read flag', () async {
    // Arrange
    await db.notificationsDao.insertIfAbsent(notificationRow('n1', DateTime.utc(2026, 11, 1)));
    await db.notificationsDao.markRead('n1');

    // Act
    await db.notificationsDao.insertIfAbsent(notificationRow('n1', DateTime.utc(2026, 11, 1)));

    // Assert
    final rows = await db.notificationsDao.watchAll().first;
    expect(rows, hasLength(1));
    expect(rows.single.row.read, isTrue);
  });

  test('markAllRead flags every unread row', () async {
    // Arrange
    await db.notificationsDao.insertIfAbsent(notificationRow('n1', DateTime.utc(2026, 11, 1)));
    await db.notificationsDao.insertIfAbsent(notificationRow('n2', DateTime.utc(2026, 11, 2)));

    // Act
    await db.notificationsDao.markAllRead();

    // Assert
    final rows = await db.notificationsDao.watchAll().first;
    expect(rows.every((r) => r.row.read), isTrue);
  });

  test('keeps only the newest maxRows notifications', () async {
    // Arrange
    final start = DateTime.utc(2026);
    for (var i = 0; i < NotificationsDao.maxRows; i++) {
      await db.notificationsDao.insertIfAbsent(notificationRow('n$i', start.add(Duration(minutes: i))));
    }

    // Act
    await db.notificationsDao.insertIfAbsent(notificationRow('newest', start.add(const Duration(days: 30))));

    // Assert
    final rows = await db.notificationsDao.watchAll().first;
    expect(rows, hasLength(NotificationsDao.maxRows));
    expect(rows.first.row.id, 'newest');
    expect(rows.map((r) => r.row.id), isNot(contains('n0')));
  });

  test('clearAll removes notifications too', () async {
    // Arrange
    await db.notificationsDao.insertIfAbsent(notificationRow('n1', DateTime.utc(2026, 11, 1)));

    // Act
    await db.clearAll();

    // Assert
    expect(await db.select(db.notifications).get(), isEmpty);
  });

  test('upgrading a v1 database adds the notifications table', () async {
    // Arrange
    final dir = await Directory.systemTemp.createTemp('giliran_db');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.sqlite');
    final v2 = AppDatabase(NativeDatabase(file));
    await v2.groupsDao.upsertAll([groupRow('g1')]);
    // Turn it back into a v1 file: no notifications table, user_version 1.
    await v2.customStatement('DROP TABLE notifications');
    await v2.customStatement('PRAGMA user_version = 1');
    await v2.close();

    // Act
    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.notificationsDao.insertIfAbsent(notificationRow('n1', DateTime.utc(2026, 11, 1)));

    // Assert
    expect(await upgraded.select(upgraded.notifications).get(), hasLength(1));
    expect(await upgraded.select(upgraded.groups).get(), hasLength(1));
    final version = await upgraded.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 2);
  });
}

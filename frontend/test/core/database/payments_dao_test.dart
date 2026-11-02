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

  test('replaceForPeriod stores the board in slot order', () async {
    // Arrange
    final rows = [
      paymentRow('pay2', 'g1', 'p1', 2),
      paymentRow('pay1', 'g1', 'p1', 1),
    ];

    // Act
    await db.paymentsDao.replaceForPeriod('p1', rows);

    // Assert
    final board = await db.paymentsDao.watchByPeriod('p1').first;
    expect(board.map((p) => p.id), ['pay1', 'pay2']);
  });

  test('markPendingCash flags the payment for sync', () async {
    // Arrange
    await db.paymentsDao.replaceForPeriod('p1', [
      paymentRow('pay1', 'g1', 'p1', 1),
    ]);

    // Act
    await db.paymentsDao.markPendingCash(
      'pay1',
      idempotencyKey: 'key-12345678',
      paidAt: DateTime.utc(2026, 11, 2),
      note: 'Bayar tunai',
    );

    // Assert
    final pending = await db.paymentsDao.getPending();
    expect(pending, hasLength(1));
    expect(pending.single.status, 'paid');
    expect(pending.single.method, 'cash');
    expect(pending.single.pendingIdempotencyKey, 'key-12345678');
  });

  test('replaceForPeriod keeps rows still waiting to sync', () async {
    // Arrange
    await db.paymentsDao.replaceForPeriod('p1', [
      paymentRow('pay1', 'g1', 'p1', 1),
      paymentRow('pay2', 'g1', 'p1', 2),
    ]);
    await db.paymentsDao.markPendingCash(
      'pay1',
      idempotencyKey: 'key-12345678',
      paidAt: DateTime.utc(2026, 11, 2),
    );

    // Act
    await db.paymentsDao.replaceForPeriod('p1', [
      paymentRow('pay1', 'g1', 'p1', 1),
      paymentRow('pay2', 'g1', 'p1', 2, status: 'pending_review'),
    ]);

    // Assert
    final board = await db.paymentsDao.watchByPeriod('p1').first;
    expect(board[0].status, 'paid');
    expect(board[0].pendingSync, isTrue);
    expect(board[1].status, 'pending_review');
  });

  test('upsertAll from the server clears the pending flag', () async {
    // Arrange
    await db.paymentsDao.replaceForPeriod('p1', [
      paymentRow('pay1', 'g1', 'p1', 1),
    ]);
    await db.paymentsDao.markPendingCash(
      'pay1',
      idempotencyKey: 'key-12345678',
      paidAt: DateTime.utc(2026, 11, 2),
    );

    // Act
    await db.paymentsDao.upsertAll([
      paymentRow('pay1', 'g1', 'p1', 1, status: 'paid'),
    ]);

    // Assert
    expect(await db.paymentsDao.getPending(), isEmpty);
  });
}

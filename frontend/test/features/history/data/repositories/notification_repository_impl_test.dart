import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/database/app_database.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/services/push_service.dart';
import 'package:giliran/features/history/data/datasource/notification_local_data_source_impl.dart';
import 'package:giliran/features/history/data/datasource/notification_remote_data_source.dart';
import 'package:giliran/features/history/data/repositories/notification_repository_impl.dart';
import 'package:giliran/features/history/domain/entities/notification_entry.dart';
import 'package:giliran/features/history/domain/usecases/mark_notifications_read_usecase.dart';
import 'package:giliran/features/history/domain/usecases/register_push_token_usecase.dart';
import 'package:giliran/features/history/domain/usecases/store_notification_usecase.dart';
import 'package:giliran/features/history/domain/usecases/watch_notifications_usecase.dart';

import '../../../../core/database/fixtures.dart';

class _FakeRemote() implements NotificationRemoteDataSource {
  final tokens = <String>[];

  @override
  Future<void> putPushToken(String token) async => tokens.add(token);
}

PushMessage _push(String id, String type, {Map<String, String> extra = const {}, DateTime? sentAt}) => PushMessage(
  id: id,
  data: {'type': type, 'group_id': 'g1', 'period_id': 'p1', ...extra},
  title: 'Judul $id',
  body: 'Isi $id',
  sentAt: sentAt,
);

void main() {
  late AppDatabase db;
  late _FakeRemote remote;
  late NotificationRepositoryImpl repository;
  final now = DateTime.utc(2026, 11, 3, 5);

  setUp(() async {
    db = openTestDatabase();
    remote = _FakeRemote();
    repository = NotificationRepositoryImpl(remote, NotificationLocalDataSourceImpl(db.notificationsDao));
    await db.groupsDao.upsertAll([groupRow('g1', name: 'Arisan RT 05')]);
  });
  tearDown(() => db.close());

  Future<List<NotificationEntry>> watch(NotificationFilter filter) async =>
      (await WatchNotificationsUseCase(repository)(filter).first).getOrElse((_) => const []);

  test('a stored push carries its data keys and the cached group name', () async {
    // Arrange
    final store = StoreNotificationUseCase(repository, () => now);

    // Act
    final id = await store(_push('m1', 'payment.proof_uploaded', extra: {'payment_id': 'pay1'}));

    // Assert
    expect(id, const Right<Failure, String?>('m1'));
    final entry = (await watch(NotificationFilter.all)).single;
    expect(entry.kind, PushKind.proofUploaded);
    expect(entry.groupName, 'Arisan RT 05');
    expect(entry.paymentId, 'pay1');
    expect(entry.createdAt, now);
    expect(entry.read, isFalse);
  });

  test('a push without a type is not stored', () async {
    // Arrange
    final store = StoreNotificationUseCase(repository, () => now);

    // Act
    final result = await store(const PushMessage(id: 'x', title: 'Tes dari konsol'));

    // Assert
    expect(result, const Right<Failure, String?>(null));
    expect(await watch(NotificationFilter.all), isEmpty);
  });

  test('a push without an FCM id is stored once', () async {
    // Arrange
    final store = StoreNotificationUseCase(repository, () => now);
    const message = PushMessage(data: {'type': 'draw.completed', 'group_id': 'g1', 'period_id': 'p1'});

    // Act
    await store(message);
    await store(message);

    // Assert
    expect(await watch(NotificationFilter.all), hasLength(1));
  });

  test('filters: unread, and needs action (unread and actionable)', () async {
    // Arrange
    final store = StoreNotificationUseCase(repository, () => now);
    await store(_push('r1', 'payment.reminder', sentAt: DateTime.utc(2026, 11, 1)));
    await store(_push('a1', 'payment.approved', sentAt: DateTime.utc(2026, 11, 2)));
    await store(_push('r2', 'payment.rejected', sentAt: DateTime.utc(2026, 11, 3)));
    await MarkNotificationsReadUseCase(repository)('r2');

    // Act
    final all = await watch(NotificationFilter.all);
    final unread = await watch(NotificationFilter.unread);
    final action = await watch(NotificationFilter.needsAction);

    // Assert
    expect(all.map((e) => e.id), ['r2', 'a1', 'r1']);
    expect(unread.map((e) => e.id), ['a1', 'r1']);
    expect(action.map((e) => e.id), ['r1']);
  });

  test('mark all read empties the unread filter', () async {
    // Arrange
    final store = StoreNotificationUseCase(repository, () => now);
    await store(_push('r1', 'payment.reminder'));
    await store(_push('a1', 'payment.approved'));

    // Act
    await MarkNotificationsReadUseCase(repository)(null);

    // Assert
    expect(await watch(NotificationFilter.unread), isEmpty);
  });

  test('RegisterPushTokenUseCase saves the token and rejects a blank one', () async {
    // Arrange
    final register = RegisterPushTokenUseCase(repository);

    // Act
    final saved = await register(' fcm-1 ');
    final blank = await register('  ');

    // Assert
    expect(saved.isRight(), isTrue);
    expect(blank.getLeft().toNullable(), isA<ValidationFailure>());
    expect(remote.tokens, ['fcm-1']);
  });
}

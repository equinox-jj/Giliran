import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/app/push_controller.dart';
import 'package:giliran/app/router.dart';
import 'package:giliran/core/database/app_database.dart';
import 'package:giliran/core/services/push_service.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/history/data/datasource/notification_remote_data_source.dart';
import 'package:giliran/features/history/data/datasource/notification_remote_data_source_impl.dart';
import 'package:giliran/features/history/domain/entities/notification_entry.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/database/fixtures.dart';
import '../helpers/fake_push_service.dart';

/// A session whose status the test moves by hand.
class _FakeSession(final AuthStatus _initial) extends AuthSessionController {
  @override
  Future<AuthStatus> build() async => _initial;

  void set(AuthStatus status) => state = AsyncData(status);
}

class _FakeRemote() implements NotificationRemoteDataSource {
  final tokens = <String>[];

  @override
  Future<void> putPushToken(String token) async => tokens.add(token);
}

const _draw = PushMessage(
  id: 'm1',
  data: {'type': 'draw.completed', 'group_id': 'g1', 'period_id': 'p1'},
  title: 'Hasil kocokan',
);

void main() {
  late AppDatabase db;
  late FakePushService push;
  late _FakeRemote remote;
  late GoRouter router;

  setUp(() {
    db = openTestDatabase();
    push = FakePushService();
    remote = _FakeRemote();
    router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
    );
  });
  tearDown(() async {
    router.dispose();
    await db.close();
  });

  Future<ProviderContainer> start(AuthStatus status) async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        pushServiceProvider.overrideWithValue(push),
        notificationRemoteDataSourceProvider.overrideWithValue(remote),
        routerProvider.overrideWithValue(router),
        authSessionControllerProvider.overrideWith(() => _FakeSession(status)),
      ],
    );
    addTearDown(container.dispose);
    container
      ..listen(authSessionControllerProvider, (_, _) {})
      ..read(pushControllerProvider);
    await pumpEventQueue();
    return container;
  }

  String location() => router.routeInformationProvider.value.uri.toString();

  test('a foreground push is stored for the Aktivitas tab', () async {
    // Arrange
    await start(const AuthStatus.unlocked());

    // Act
    push.receive(_draw);
    await pumpEventQueue();

    // Assert
    final rows = await db.notificationsDao.watchAll().first;
    expect(rows.single.row.id, 'm1');
    expect(rows.single.row.read, isFalse);
  });

  test('a signed-in session saves the token, and again on refresh', () async {
    // Arrange
    await start(const AuthStatus.unlocked());

    // Act
    push.refreshToken('fcm-2');
    await pumpEventQueue();

    // Assert
    expect(push.initCount, 1);
    expect(remote.tokens, ['fcm-1', 'fcm-2']);
  });

  test('signed out saves no token; signing in saves it', () async {
    // Arrange
    final container = await start(const AuthStatus.signedOut());
    expect(remote.tokens, isEmpty);

    // Act
    (container.read(authSessionControllerProvider.notifier) as _FakeSession).set(const AuthStatus.unlocked());
    await pumpEventQueue();

    // Assert
    expect(remote.tokens, ['fcm-1']);
  });

  test('a tap stores it read and opens Bukti Kocok', () async {
    // Arrange
    await start(const AuthStatus.unlocked());

    // Act
    push.tap(_draw);
    await pumpEventQueue();

    // Assert
    expect(location(), '/groups/g1/periods/p1/draw/result');
    final rows = await db.notificationsDao.watchAll().first;
    expect(rows.single.row.read, isTrue);
  });

  test('a tap while locked waits for the unlock', () async {
    // Arrange
    final container = await start(const AuthStatus.locked());
    push.tap(_draw);
    await pumpEventQueue();
    expect(location(), '/');
    expect(container.read(pushControllerProvider.notifier).pending, isA<DrawResultTarget>());

    // Act
    (container.read(authSessionControllerProvider.notifier) as _FakeSession).set(const AuthStatus.unlocked());
    await pumpEventQueue();

    // Assert
    expect(location(), '/groups/g1/periods/p1/draw/result');
  });

  test('the notification that launched the app is opened', () async {
    // Arrange
    push.launchMessage = const PushMessage(
      id: 'm2',
      data: {'type': 'payment.proof_uploaded', 'group_id': 'g1', 'payment_id': 'pay1'},
    );

    // Act
    await start(const AuthStatus.unlocked());

    // Assert
    expect(location(), '/groups/g1/payments/pay1/review');
  });

  test('notificationLocation maps every target to its route', () {
    // Act & Assert
    expect(notificationLocation(const InboxTarget()), '/activity');
    expect(notificationLocation(const GroupTarget('g1')), '/groups/g1');
    expect(notificationLocation(const GroupTarget('g1', tab: GroupTargetTab.payments)), '/groups/g1?tab=pembayaran');
    expect(notificationLocation(const GroupTarget('g1', tab: GroupTargetTab.members)), '/groups/g1?tab=anggota');
    expect(notificationLocation(const PayoutTarget('g1', 'p1')), '/groups/g1/periods/p1/payout');
  });
}

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/database/app_database.dart';
import 'package:giliran/core/services/push_service.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/features/history/domain/entities/notification_entry.dart';
import 'package:giliran/features/history/presentation/notifications/page/notifications_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../core/database/fixtures.dart';
import '../../../../../helpers/fake_push_service.dart';
import '../../../../../helpers/pump_app.dart';

/// Now: Tue 3 Nov 2026, 10.00 in Jakarta.
final _now = DateTime.utc(2026, 11, 3, 3);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late AppDatabase db;
  late FakePushService push;
  late List<NotificationTarget> opened;

  setUp(() async {
    db = openTestDatabase();
    push = FakePushService();
    opened = [];
    await db.groupsDao.upsertAll([groupRow('g1', name: 'Arisan RT 05')]);
  });
  tearDown(() => db.close());

  Future<void> store(String id, DateTime at, {String type = 'payment.reminder', bool read = false}) =>
      db.notificationsDao.insertIfAbsent(
        notificationRow(id, at, type: type, read: read).copyWith(
          periodId: const Value('p1'),
          paymentId: const Value('pay1'),
        ),
      );

  Future<void> pumpPage(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        pushServiceProvider.overrideWithValue(push),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(NotificationsPage(onOpen: opened.add), container: container);
    await tester.pumpAndSettle();
  }

  testWidgets('stored pushes show grouped by day with the group name', (tester) async {
    // Arrange
    await store('n2', DateTime.utc(2026, 11, 3, 2));
    await store('n1', DateTime.utc(2026, 11, 2, 2));

    // Act
    await pumpPage(tester);

    // Assert
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Kemarin'), findsOneWidget);
    expect(find.text('Arisan RT 05'), findsNWidgets(2));
    expect(find.text('Judul n2'), findsOneWidget);
    expect(find.text('09.00'), findsNWidgets(2));
  });

  testWidgets('chips filter Belum dibaca and Perlu tindakan', (tester) async {
    // Arrange
    await store('reminder', DateTime.utc(2026, 11, 3, 2));
    await store('approved', DateTime.utc(2026, 11, 3, 1), type: 'payment.approved');
    await store('old', DateTime.utc(2026, 11, 3, 0), read: true);
    await pumpPage(tester);
    expect(find.byType(NotificationItem), findsNWidgets(3));

    // Act
    await tester.tap(find.text('Belum dibaca'));
    await tester.pumpAndSettle();
    final unread = tester.widgetList(find.byType(NotificationItem)).length;
    await tester.tap(find.text('Perlu tindakan'));
    await tester.pumpAndSettle();

    // Assert
    expect(unread, 2);
    expect(find.byType(NotificationItem), findsOneWidget);
    expect(find.text('Judul reminder'), findsOneWidget);
  });

  testWidgets('Tandai semua dibaca marks every item read', (tester) async {
    // Arrange
    await store('n1', DateTime.utc(2026, 11, 3, 2));
    await store('n2', DateTime.utc(2026, 11, 3, 1));
    await pumpPage(tester);

    // Act
    await tester.tap(find.text('Tandai semua dibaca'));
    await tester.pumpAndSettle();

    // Assert
    final items = tester.widgetList<NotificationItem>(find.byType(NotificationItem));
    expect(items.every((i) => i.read), isTrue);
  });

  testWidgets('tapping an item marks it read and opens its target', (tester) async {
    // Arrange
    await store('n1', DateTime.utc(2026, 11, 3, 2), type: 'payment.proof_uploaded');
    await pumpPage(tester);

    // Act
    await tester.tap(find.byType(NotificationItem));
    await tester.pumpAndSettle();

    // Assert
    expect(opened.single, isA<ProofReviewTarget>());
    expect(tester.widget<NotificationItem>(find.byType(NotificationItem)).read, isTrue);
  });

  testWidgets('no notifications shows "Belum ada aktivitas."', (tester) async {
    // Act
    await pumpPage(tester);

    // Assert
    expect(find.text('Belum ada aktivitas.'), findsOneWidget);
  });

  testWidgets('push off shows the banner, and its action opens the settings', (tester) async {
    // Arrange
    push.permissionState = PushPermission.denied;
    await pumpPage(tester);
    expect(find.text('Notifikasi mati. Aktifkan agar tidak lupa iuran.'), findsOneWidget);

    // Act
    await tester.tap(find.text('Buka pengaturan'));
    await tester.pumpAndSettle();

    // Assert
    expect(push.settingsOpened, 1);
  });

  testWidgets('push on shows no banner', (tester) async {
    // Act
    await pumpPage(tester);

    // Assert
    expect(find.text('Notifikasi mati. Aktifkan agar tidak lupa iuran.'), findsNothing);
  });
}

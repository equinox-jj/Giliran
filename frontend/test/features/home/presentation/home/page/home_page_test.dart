import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/network/connectivity_controller.dart';
import 'package:giliran/core/services/biometric_service.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/home/presentation/home/page/home_page.dart';
import 'package:giliran/features/home/presentation/home/widgets/group_carousel.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/a11y.dart';
import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/fake_connectivity.dart';
import '../../../../../helpers/fake_group_repository.dart';
import '../../../../../helpers/group_fixtures.dart';
import '../../../../../helpers/pump_app.dart';

final _now = DateTime.utc(2026, 11, 4, 3);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late List<String> opened;

  setUp(() {
    groups = FakeGroupRepository();
    opened = [];
  });

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    bool online = true,
    Size size = const Size(390, 844),
  }) async {
    final auth = FakeAuthRepository()..userResult = Right(ProfileData(name: 'Joshua Jeremia', pinSet: true));
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        groupRepositoryProvider.overrideWithValue(groups),
        clockProvider.overrideWithValue(() => _now),
        connectivityControllerProvider.overrideWith(() => FakeConnectivityController(online)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authSessionControllerProvider.future);
    container.read(authSessionControllerProvider.notifier).unlock();
    await tester.pumpPage(
      HomePage(
        onOpenGroup: (id) => opened.add('group:$id'),
        onCreateGroup: () => opened.add('create'),
        onJoinByLink: () => opened.add('join'),
      ),
      container: container,
      size: size,
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('fits a 360 dp phone at 130 percent text and meets the a11y guidelines', (tester) async {
    // Arrange
    final semantics = tester.ensureSemantics();
    useLargeText(tester);
    groups.groups = [
      summary('a', payment: PaymentStatus.unpaid, due: DateTime.utc(2026, 11, 20)),
      summary('b'),
    ];

    // Act
    await pumpHome(tester, size: a11yPhone);

    // Assert
    await expectAccessibleScreen(tester);
    semantics.dispose();
  });

  testWidgets('headline counts my open dues', (tester) async {
    // Arrange
    groups.groups = [
      summary('a', payment: PaymentStatus.unpaid, due: DateTime.utc(2026, 11, 20)),
      summary('b', payment: PaymentStatus.rejected, due: DateTime.utc(2026, 11, 22)),
      summary('c'),
    ];

    // Act
    await pumpHome(tester);

    // Assert
    expect(find.text('Halo, Joshua. 2 iuran menunggu bulan ini.'), findsOneWidget);
  });

  testWidgets('headline says all settled when everything is paid', (tester) async {
    // Arrange
    groups.groups = [summary('a')];

    // Act
    await pumpHome(tester);

    // Assert
    expect(find.text('Semua iuran sudah beres.'), findsOneWidget);
  });

  testWidgets('no groups shows the empty state with create and join', (tester) async {
    // Arrange
    groups.groups = [];
    await pumpHome(tester);

    // Act
    await tester.tap(find.text('Buat grup'));
    await tester.tap(find.text('Gabung pakai link'));

    // Assert
    expect(find.text('Belum ada arisan. Yuk mulai.'), findsOneWidget);
    expect(opened, ['create', 'join']);
  });

  testWidgets('the hero shows the most urgent item and opens its group', (tester) async {
    // Arrange
    groups.groups = [
      summary('a', name: 'Arisan RT 05', payment: PaymentStatus.rejected, due: DateTime.utc(2026, 11, 20)),
    ];
    await pumpHome(tester);

    // Act
    await tester.tap(find.text('Upload ulang bukti'));

    // Assert
    expect(find.text('Bukti kamu ditolak'), findsOneWidget);
    expect(opened, ['group:a']);
  });

  testWidgets('the hero is calm when nothing is urgent', (tester) async {
    // Arrange
    groups.groups = [summary('a', due: DateTime.utc(2026, 11, 20))];

    // Act
    await pumpHome(tester);

    // Assert
    expect(find.text('Tidak ada yang perlu dilakukan'), findsOneWidget);
  });

  testWidgets('filter chips narrow the carousel', (tester) async {
    // Arrange
    groups.groups = [
      summary('org', name: 'Arisan Pengurus', role: MemberRole.organizer, due: DateTime.utc(2026, 11, 20)),
      summary('mem', name: 'Arisan Anggota', due: DateTime.utc(2026, 11, 21)),
    ];
    await pumpHome(tester);

    // Act
    await tester.tap(find.widgetWithText(AppChip, 'Saya pengurus'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.widgetWithText(GroupCard, 'Arisan Pengurus'), findsOneWidget);
    expect(find.widgetWithText(GroupCard, 'Arisan Anggota'), findsNothing);
    expect(find.widgetWithText(AppChip, 'Semua'), findsOneWidget);
    expect(find.widgetWithText(AppChip, 'Belum bayar'), findsOneWidget);
  });

  testWidgets('the carousel ends with the create or join card', (tester) async {
    // Arrange
    groups.groups = [summary('a', due: DateTime.utc(2026, 11, 20))];
    await pumpHome(tester);

    // Act
    await tester.scrollUntilVisible(find.byType(CreateOrJoinCard), 200, scrollable: find.byType(Scrollable).last);

    // Assert
    expect(find.byType(CreateOrJoinCard), findsOneWidget);
  });

  testWidgets('pull to refresh fetches the groups again', (tester) async {
    // Arrange
    groups.groups = [summary('a', due: DateTime.utc(2026, 11, 20))];
    await pumpHome(tester);
    final before = groups.refreshedFilters.length;

    // Act
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    // Assert
    expect(groups.refreshedFilters.length, before + 1);
  });

  testWidgets('shows the offline banner when offline', (tester) async {
    // Arrange
    groups.groups = [summary('a', due: DateTime.utc(2026, 11, 20))];

    // Act
    await pumpHome(tester, online: false);

    // Assert
    expect(find.byType(OfflineBanner), findsOneWidget);
  });

  testWidgets('no offline banner when online', (tester) async {
    // Arrange
    groups.groups = [summary('a', due: DateTime.utc(2026, 11, 20))];

    // Act
    await pumpHome(tester);

    // Assert
    expect(find.byType(OfflineBanner), findsNothing);
  });
}

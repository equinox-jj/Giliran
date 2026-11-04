import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/connectivity_controller.dart';
import 'package:giliran/core/services/image_picker_service.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/period_status.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:giliran/features/payment/domain/entities/payout.dart';
import 'package:giliran/features/payment/domain/entities/period.dart';
import 'package:giliran/features/payment/presentation/payout/page/payout_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fake_connectivity.dart';
import '../../../../helpers/fake_group_repository.dart';
import '../../../../helpers/fake_image_picker_service.dart';
import '../../../../helpers/fake_payment_repository.dart';
import '../../../../helpers/pump_app.dart';

const _winner = MemberRef(id: 'm5', displayName: 'Bu Rina', slotNo: 5);

const _organizer = GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  status: GroupStatus.active,
  myRole: MemberRole.organizer,
  myMemberId: 'm1',
  amount: 200000,
  potAmount: 2000000,
  totalSlots: 10,
);

final _recorded = Payout(
  id: 'po1',
  periodId: 'p1',
  winner: _winner,
  amount: 2000000,
  recordedBy: const UserSummary(id: 'u1', name: 'Pak Budi'),
  recordedAt: DateTime.utc(2026, 10, 26, 13),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late FakePaymentRepository payments;
  late FakeImagePickerService picker;

  setUp(() {
    groups = FakeGroupRepository()
      ..group = _organizer
      ..groupResult = null;
    payments = FakePaymentRepository()
      ..periods = [const Period(id: 'p1', periodNo: 4, status: PeriodStatus.drawn, winner: _winner)]
      ..payoutResult = Right(_recorded);
    picker = FakeImagePickerService();
  });

  Future<void> pumpPayout(WidgetTester tester, {bool online = true}) async {
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        paymentRepositoryProvider.overrideWithValue(payments),
        imagePickerServiceProvider.overrideWithValue(picker),
        connectivityControllerProvider.overrideWith(() => FakeConnectivityController(online)),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 26, 14)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      PayoutPage(groupId: 'g1', periodId: 'p1', onClose: () {}),
      container: container,
      size: const Size(390, 1400),
    );
    await tester.pumpAndSettle();
  }

  AppButton recordButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, 'Catat penyerahan'));

  Future<void> record(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(AppButton, 'Catat penyerahan'));
    await tester.pumpAndSettle();
  }

  group('organizer before recording', () {
    testWidgets('shows the pot, the winner and needs "Uang sudah saya serahkan"', (tester) async {
      // Arrange
      await pumpPayout(tester);

      // Act
      final before = recordButton(tester).onPressed;
      await tester.tap(find.text('Uang sudah saya serahkan'));
      await tester.pump();

      // Assert
      expect(find.textContaining('Serahkan Rp2.000.000 ke Bu Rina', findRichText: true), findsOneWidget);
      expect(find.text('Slot 05'), findsOneWidget);
      expect(before, isNull);
      expect(recordButton(tester).onPressed, isNotNull);
    });

    testWidgets('records with an optional proof, the note and an idempotency key', (tester) async {
      // Arrange
      await pumpPayout(tester);

      // Act
      await tester.tap(find.byType(UploadTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Galeri'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Tunai di rumah  ');
      await tester.tap(find.text('Uang sudah saya serahkan'));
      await tester.pump();
      await record(tester);

      // Assert
      expect(payments.calls, contains('recordPayout'));
      expect(payments.lastPath, '/tmp/photo.jpg');
      expect(payments.lastNote, 'Tunai di rumah');
      expect(payments.keys, hasLength(1));
      expect(find.text('Menunggu konfirmasi Bu Rina'), findsOneWidget);
    });

    testWidgets('record retry reuses the idempotency key', (tester) async {
      // Arrange
      payments.payoutWriteResults.add(const Left(Failure.timeout()));
      await pumpPayout(tester);
      await tester.tap(find.text('Uang sudah saya serahkan'));
      await tester.pump();

      // Act
      await record(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await record(tester);

      // Assert
      expect(payments.keys, hasLength(2));
      expect(payments.keys.first, payments.keys.last);
    });

    testWidgets('payout_already_recorded tells and refreshes', (tester) async {
      // Arrange
      payments.payoutWriteResults.add(const Left(Failure.conflict(code: ApiErrorCode.payoutAlreadyRecorded)));
      await pumpPayout(tester);
      await tester.tap(find.text('Uang sudah saya serahkan'));
      await tester.pump();

      // Act
      await record(tester);

      // Assert
      expect(find.text('Penyerahan sudah dicatat pengurus lain.'), findsOneWidget);
      expect(payments.calls.where((c) => c == 'getPayout'), hasLength(2));
    });

    testWidgets('offline disables recording', (tester) async {
      // Arrange
      await pumpPayout(tester, online: false);

      // Act
      await tester.tap(find.text('Uang sudah saya serahkan'));
      await tester.pump();

      // Assert
      expect(recordButton(tester).onPressed, isNull);
    });
  });

  testWidgets('recorded shows "Menunggu konfirmasi {winner}"', (tester) async {
    // Arrange
    payments.payout = _recorded;

    // Act
    await pumpPayout(tester);

    // Assert
    expect(find.text('Menunggu konfirmasi Bu Rina'), findsOneWidget);
    expect(find.textContaining('Dicatat Pak Budi'), findsOneWidget);
  });

  group('winner', () {
    setUp(() {
      groups.group = _organizer.copyWith(myRole: MemberRole.member, myMemberId: 'm5');
      payments.payout = _recorded;
    });

    testWidgets('confirms receipt with its own key', (tester) async {
      // Arrange
      payments.payoutResult = Right(_recorded.copyWith(confirmedAt: DateTime.utc(2026, 10, 26, 14)));
      await pumpPayout(tester);

      // Act
      final asked = find.textContaining('Sudah terima Rp2.000.000?', findRichText: true).evaluate().isNotEmpty;
      await tester.tap(find.text('Ya, sudah saya terima'));
      await tester.pumpAndSettle();

      // Assert
      expect(asked, isTrue);
      expect(payments.calls, contains('confirmPayout'));
      expect(payments.keys, hasLength(1));
      expect(find.textContaining('Diterima Bu Rina'), findsOneWidget);
    });

    testWidgets('"Belum terima" only opens advice, nothing is sent', (tester) async {
      // Arrange
      await pumpPayout(tester);

      // Act
      await tester.tap(find.text('Belum terima'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Belum terima uangnya?'), findsOneWidget);
      expect(payments.calls, isNot(contains('confirmPayout')));
    });
  });

  testWidgets('confirmed shows "Diterima {winner} · {date}"', (tester) async {
    // Arrange
    groups.group = _organizer.copyWith(myRole: MemberRole.member, myMemberId: 'm2');
    payments.payout = _recorded.copyWith(confirmedAt: DateTime.utc(2026, 10, 26, 13, 30));

    // Act
    await pumpPayout(tester);

    // Assert
    expect(find.text('Diterima Bu Rina · 30 menit lalu'), findsOneWidget);
  });

  testWidgets('members see that nothing is recorded yet', (tester) async {
    // Arrange
    groups.group = _organizer.copyWith(myRole: MemberRole.member, myMemberId: 'm2');

    // Act
    await pumpPayout(tester);

    // Assert
    expect(find.text('Pengurus belum mencatat penyerahan.'), findsOneWidget);
  });
}

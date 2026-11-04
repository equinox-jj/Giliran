import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/period_status.dart';
import 'package:giliran/core/utils/enums/period_type.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/history/data/repositories/history_repository_impl.dart';
import 'package:giliran/features/history/presentation/group_summary/page/group_summary_page.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:giliran/features/payment/domain/entities/payment.dart';
import 'package:giliran/features/payment/domain/entities/period.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/fake_group_repository.dart';
import '../../../../../helpers/fake_history_repository.dart';
import '../../../../../helpers/fake_payment_repository.dart';
import '../../../../../helpers/pump_app.dart';

final _completed = GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  amount: 200000,
  periodType: PeriodType.monthly,
  totalSlots: 3,
  status: GroupStatus.completed,
  myRole: MemberRole.member,
  completedAt: DateTime.utc(2026, 3, 6),
);

List<Period> _periods({int drawn = 3}) => [
  for (var n = 1; n <= 3; n++)
    Period(
      id: 'p$n',
      groupId: 'g1',
      periodNo: n,
      drawDate: DateTime.utc(2026, n, 5),
      status: n <= drawn ? PeriodStatus.closed : PeriodStatus.upcoming,
      drawnAt: n <= drawn ? DateTime.utc(2026, n, 5, 12) : null,
      winner: n <= drawn ? MemberRef(id: 'm$n', displayName: 'Pemenang $n') : null,
      paymentSummary: n <= drawn ? const PaymentSummary(paidCount: 3, totalCount: 3, collectedAmount: 600000) : null,
    ),
];

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late FakePaymentRepository payments;
  late List<NewCyclePrefill> created;
  late List<String> proofs;

  setUp(() {
    groups = FakeGroupRepository();
    payments = FakePaymentRepository();
    created = [];
    proofs = [];
  });

  Future<void> pumpSummary(WidgetTester tester, GroupDetail group, {List<Period>? periods}) async {
    groups
      ..group = group
      ..groupResult = null;
    payments.periods = periods ?? _periods();
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        paymentRepositoryProvider.overrideWithValue(payments),
        historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      GroupSummaryPage(groupId: 'g1', onCreateNew: created.add, onBuktiKocok: proofs.add),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a completed group reads "Arisan selesai. 3 periode, 3 pemenang."', (tester) async {
    // Act
    await pumpSummary(tester, _completed);

    // Assert
    expect(find.text('Arisan selesai. 3 periode, 3 pemenang.'), findsOneWidget);
    expect(find.text('Rp1.800.000'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Arisan sudah selesai'), findsOneWidget);
  });

  testWidgets('a group closed early says so and marks undrawn periods', (tester) async {
    // Act
    await pumpSummary(
      tester,
      _completed.copyWith(status: GroupStatus.closed, completedAt: null, closedAt: DateTime.utc(2026, 2, 20)),
      periods: _periods(drawn: 1),
    );

    // Assert
    expect(find.text('Arisan ditutup Jum, 20 Feb'), findsOneWidget);
    expect(find.text('1 dari 3 periode sempat dikocok.'), findsOneWidget);
    expect(find.text('Tidak dikocok'), findsNWidgets(2));
    expect(find.text('Arisan sudah ditutup'), findsOneWidget);
  });

  testWidgets('the organizer starts a new arisan prefilled from this one', (tester) async {
    // Arrange
    await pumpSummary(tester, _completed.copyWith(myRole: MemberRole.organizer));
    expect(find.text('Lihat riwayat'), findsNothing);

    // Act
    await tester.tap(find.text('Buat arisan baru'));
    await tester.pumpAndSettle();

    // Assert
    expect(created.single, (amount: 200000, periodType: PeriodType.monthly, totalSlots: 3));
  });

  testWidgets('members get Lihat riwayat, which opens the Aktivitas tab', (tester) async {
    // Arrange
    await pumpSummary(tester, _completed);
    expect(find.text('Buat arisan baru'), findsNothing);

    // Act
    await tester.tap(find.text('Lihat riwayat'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Semua perubahan oleh pengurus tercatat di sini dan tidak bisa dihapus.'), findsOneWidget);
  });

  testWidgets('a winner row opens its Bukti Kocok', (tester) async {
    // Arrange
    await pumpSummary(tester, _completed);

    // Act
    await tester.tap(find.widgetWithText(AppTextButton, 'Bukti').first);

    // Assert
    expect(proofs, ['p1']);
  });

  testWidgets('the tabs are read-only: no payment or member actions', (tester) async {
    // Act
    await pumpSummary(tester, _completed.copyWith(myRole: MemberRole.organizer));

    // Assert
    expect(find.text('Pembayaran'), findsNothing);
    expect(find.text('Undang'), findsNothing);
    expect(find.text('Kocok'), findsNothing);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/payment_method.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/core/utils/enums/period_status.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:giliran/features/payment/domain/entities/payment.dart';
import 'package:giliran/features/payment/domain/entities/period.dart';
import 'package:giliran/features/payment/presentation/payments_tab/widgets/payments_tab.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fake_payment_repository.dart';
import '../../../../helpers/pump_app.dart';

const _group = GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  amount: 200000,
  status: GroupStatus.active,
  myRole: MemberRole.member,
);
final _organizerGroup = _group.copyWith(myRole: MemberRole.organizer);

final _open = Period(
  id: 'p1',
  periodNo: 4,
  status: PeriodStatus.open,
  dueDate: DateTime.utc(2026, 11, 1),
  drawDate: DateTime.utc(2026, 11, 5),
);

Payment _payment(
  String id,
  int slot,
  PaymentStatus status, {
  String name = 'Anggota',
  bool mine = false,
  bool guest = false,
  PaymentMethod? method,
  String? reason,
}) => Payment(
  id: id,
  periodId: 'p1',
  member: MemberRef(id: 'm$slot', displayName: name, slotNo: slot, isGuest: guest),
  amount: 200000,
  status: status,
  method: method,
  rejectReason: reason,
  paidAt: status == PaymentStatus.paid ? DateTime.utc(2026, 11, 3, 5) : null,
  currentProof: status == PaymentStatus.pendingReview ? const PaymentProof(id: 'pr1') : null,
  updatedAt: DateTime.utc(2026, 11, 3, 12, 2),
  isMine: mine,
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakePaymentRepository payments;
  late List<String> actions;

  setUp(() {
    payments = FakePaymentRepository();
    actions = [];
  });

  Future<void> pumpTab(WidgetTester tester, {GroupDetail group = _group, Period? period}) async {
    final container = ProviderContainer(
      overrides: [
        paymentRepositoryProvider.overrideWithValue(payments),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      Scaffold(
        body: CustomScrollView(
          slivers: [
            PaymentsTab(
              group: group,
              period: period ?? _open,
              actions: (
                onUpload: (p) => actions.add('upload:${p.id}'),
                onReview: (p) => actions.add('review:${p.id}'),
                onViewProof: (p) => actions.add('view:${p.id}'),
                onMarkPaid: (p) => actions.add('markPaid:${p.id}'),
                onRemind: (p) => actions.add('remind:${p.id}'),
              ),
            ),
          ],
        ),
      ),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pins my row first in ink, then orders by slot', (tester) async {
    // Arrange
    payments.payments = [
      _payment('a', 1, PaymentStatus.paid, name: 'Bu Sari'),
      _payment('b', 5, PaymentStatus.unpaid, name: 'Kamu', mine: true),
      _payment('c', 2, PaymentStatus.paid, name: 'Pak Dedi'),
    ];

    // Act
    await pumpTab(tester);

    // Assert
    final rows = tester.widgetList<PaymentRow>(find.byType(PaymentRow)).toList();
    expect(rows.map((r) => r.name), ['Kamu', 'Bu Sari', 'Pak Dedi']);
    expect(rows.first.mine, isTrue);
  });

  testWidgets('each status has its subtitle, overdue in bata', (tester) async {
    // Arrange
    payments.payments = [
      _payment('a', 1, PaymentStatus.paid, method: PaymentMethod.cash),
      _payment('b', 2, PaymentStatus.pendingReview),
      _payment('c', 3, PaymentStatus.rejected, reason: 'Nominal kurang'),
      _payment('d', 4, PaymentStatus.unpaid),
    ];

    // Act
    await pumpTab(tester);

    // Assert
    expect(find.text('Dibayar Kemarin · Tunai'), findsOneWidget);
    expect(find.text('Upload Kemarin'), findsOneWidget);
    expect(find.text('Nominal kurang'), findsOneWidget);
    expect(find.text('Jatuh tempo Min, 1 Nov'), findsOneWidget);
    final unpaid = tester.widget<PaymentRow>(find.widgetWithText(PaymentRow, 'Jatuh tempo Min, 1 Nov'));
    expect(unpaid.subtitleAlert, isTrue);
    expect(unpaid.status, ChipStatus.overdue);
  });

  testWidgets('guest rows show Tamu', (tester) async {
    // Arrange
    payments.payments = [_payment('a', 1, PaymentStatus.unpaid, name: 'Bu Sri', guest: true)];

    // Act
    await pumpTab(tester);

    // Assert
    expect(find.text('TAMU'), findsOneWidget);
  });

  testWidgets('filter chips are for organizers only', (tester) async {
    // Arrange
    payments.payments = [_payment('a', 1, PaymentStatus.unpaid)];

    // Act
    await pumpTab(tester);

    // Assert
    expect(find.text('Menunggu cek'), findsNothing);
    expect(find.byType(AppChip), findsNothing);
  });

  testWidgets('Menunggu cek narrows the board for organizers', (tester) async {
    // Arrange
    payments.payments = [
      _payment('a', 1, PaymentStatus.unpaid, name: 'Bu Sari'),
      _payment('b', 2, PaymentStatus.pendingReview, name: 'Pak Dedi'),
    ];
    await pumpTab(tester, group: _organizerGroup);

    // Act
    await tester.tap(find.widgetWithText(AppChip, 'Menunggu cek'));
    await tester.pumpAndSettle();

    // Assert
    final rows = tester.widgetList<PaymentRow>(find.byType(PaymentRow)).toList();
    expect(rows.map((r) => r.name), ['Pak Dedi']);
  });

  testWidgets('an organizer taps a pending row to review it', (tester) async {
    // Arrange
    payments.payments = [_payment('b', 2, PaymentStatus.pendingReview, name: 'Pak Dedi')];
    await pumpTab(tester, group: _organizerGroup);

    // Act
    await tester.tap(find.text('Pak Dedi'));

    // Assert
    expect(actions, ['review:b']);
  });

  testWidgets('an unpaid row offers Tandai sudah bayar and the WhatsApp reminder', (tester) async {
    // Arrange
    payments.payments = [_payment('a', 1, PaymentStatus.unpaid, name: 'Bu Sari')];
    await pumpTab(tester, group: _organizerGroup);
    await tester.tap(find.byType(OverflowMenuButton));
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.text('Tandai sudah bayar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OverflowMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingatkan lewat WhatsApp'));
    await tester.pumpAndSettle();

    // Assert
    expect(actions, ['markPaid:a', 'remind:a']);
  });

  testWidgets('my unpaid row opens the upload sheet', (tester) async {
    // Arrange
    payments.payments = [_payment('b', 5, PaymentStatus.unpaid, name: 'Kamu', mine: true)];
    await pumpTab(tester);

    // Act
    await tester.tap(find.text('Kamu'));

    // Assert
    expect(actions, ['upload:b']);
  });

  testWidgets('my rejected proof shows the reason banner', (tester) async {
    // Arrange
    payments.payments = [
      _payment('b', 5, PaymentStatus.rejected, name: 'Kamu', mine: true, reason: 'Bukti tidak jelas'),
    ];

    // Act
    await pumpTab(tester);

    // Assert
    expect(find.text('Bukti kamu ditolak: Bukti tidak jelas'), findsOneWidget);
  });

  testWidgets('an upcoming period shows the empty state', (tester) async {
    // Act
    await pumpTab(tester, period: _open.copyWith(status: PeriodStatus.upcoming));

    // Assert
    expect(find.text('Periode ini belum dibuka'), findsOneWidget);
    expect(payments.calls, isEmpty);
  });

  testWidgets('everyone paid shows the success banner', (tester) async {
    // Arrange
    payments.payments = [
      _payment('a', 1, PaymentStatus.paid),
      _payment('b', 2, PaymentStatus.paid),
    ];

    // Act
    await pumpTab(tester);

    // Assert
    expect(find.text('Semua sudah bayar periode ini.'), findsOneWidget);
    expect(find.text('2 sudah bayar · 0 menunggu cek · 0 belum'), findsOneWidget);
  });

  testWidgets('opening the tab refreshes that period', (tester) async {
    // Act
    await pumpTab(tester);

    // Assert
    expect(payments.calls, contains('refreshPeriodPayments:p1'));
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/draw_method.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/period_type.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/member/presentation/start_group/page/start_group_page.dart';
import 'package:giliran/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/failures.dart';
import '../../../../helpers/fake_group_repository.dart';
import '../../../../helpers/fake_member_repository.dart';
import '../../../../helpers/fake_payment_repository.dart';
import '../../../../helpers/pump_app.dart';

GroupDetail _group({DrawMethod draw = DrawMethod.random, int filled = 2, bool account = true}) => GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  amount: 200000,
  potAmount: 400000,
  periodType: PeriodType.monthly,
  totalSlots: 2,
  filledSlots: filled,
  drawMethod: draw,
  startDate: DateTime.utc(2026, 11, 25),
  status: GroupStatus.draft,
  myRole: MemberRole.organizer,
  paymentInfo: account ? const PaymentInfo(bankName: 'BCA', accountNumber: '1234567890') : const PaymentInfo(),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late FakeMemberRepository members;
  late FakePaymentRepository payments;
  late List<String> events;

  setUp(() {
    groups = FakeGroupRepository();
    members = FakeMemberRepository()
      ..members = const [
        Member(id: 'm1', displayName: 'Rina', slotNo: 1, fixedOrderPosition: 1),
        Member(id: 'm2', displayName: 'Dedi', slotNo: 2),
      ];
    payments = FakePaymentRepository();
    events = [];
  });

  Future<void> pumpStart(WidgetTester tester, GroupDetail group) async {
    groups
      ..group = group
      ..groupResult = null;
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        memberRepositoryProvider.overrideWithValue(members),
        paymentRepositoryProvider.overrideWithValue(payments),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      StartGroupPage(
        groupId: 'g1',
        onInvite: () => events.add('invite'),
        onPaymentInfo: () => events.add('paymentInfo'),
        onFixedOrder: () => events.add('fixedOrder'),
        onStarted: () => events.add('started'),
      ),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirmStart(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.widgetWithText(AppButton, 'Mulai arisan'), 200);
    await tester.tap(find.widgetWithText(AppButton, 'Mulai arisan'));
    await tester.pumpAndSettle();
  }

  testWidgets('a random draw lists slots and payment info only', (tester) async {
    // Act
    await pumpStart(tester, _group());

    // Assert
    expect(find.text('Semua slot terisi'), findsOneWidget);
    expect(find.text('Info rekening ada'), findsOneWidget);
    expect(find.text('Urutan lengkap'), findsNothing);
  });

  testWidgets('a fixed order adds the order item and its fix action', (tester) async {
    // Arrange
    await pumpStart(tester, _group(draw: DrawMethod.fixedOrder));

    // Act
    await tester.tap(find.text('Atur urutan'));

    // Assert
    expect(find.text('Urutan lengkap'), findsOneWidget);
    expect(events, ['fixedOrder']);
  });

  testWidgets('missing items keep the start button disabled', (tester) async {
    // Act
    await pumpStart(tester, _group(filled: 1, account: false));
    await tester.scrollUntilVisible(find.text('Lengkapi 2 hal lagi'), 200);

    // Assert
    expect(tester.widget<AppButton>(find.widgetWithText(AppButton, 'Mulai arisan')).onPressed, isNull);
  });

  testWidgets('starting needs the consent row checked', (tester) async {
    // Arrange
    await pumpStart(tester, _group());
    await confirmStart(tester);
    final confirm = find.widgetWithText(AppButton, 'Mulai arisan').last;
    final disabledFirst = tester.widget<AppButton>(confirm).onPressed == null;

    // Act
    await tester.tap(find.byType(CheckRow));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Mulai arisan').last);
    await tester.pumpAndSettle();

    // Assert
    expect(disabledFirst, isTrue);
    expect(members.calls, contains('startGroup'));
    expect(events, ['started']);
  });

  testWidgets('a started group refetches its periods so the detail shows period 1', (tester) async {
    // Arrange
    await pumpStart(tester, _group());
    await confirmStart(tester);
    await tester.tap(find.byType(CheckRow));
    await tester.pumpAndSettle();
    payments.calls.clear();

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Mulai arisan').last);
    await tester.pumpAndSettle();

    // Assert
    expect(payments.calls, contains('refreshPeriods'));
  });

  testWidgets('payment_info_missing highlights the payment info item', (tester) async {
    // Arrange
    members.startResult = Left(conflict(ApiErrorCode.paymentInfoMissing));
    await pumpStart(tester, _group());
    await confirmStart(tester);
    await tester.tap(find.byType(CheckRow));
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Mulai arisan').last);
    await tester.pumpAndSettle();

    // Assert
    final rows = tester.widget<ReadinessChecklist>(find.byType(ReadinessChecklist)).rows;
    expect(rows.where((r) => r.highlighted).single.title, 'Info rekening ada');
    expect(events, isEmpty);
  });
}

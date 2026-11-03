import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/core/utils/enums/period_type.dart';
import 'package:giliran/features/group/domain/entities/group_summary.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/pump_app.dart';

const _group = GroupSummary(
  id: 'g1',
  name: 'Arisan RT 05',
  amount: 200000,
  periodType: PeriodType.monthly,
  status: GroupStatus.active,
  myRole: MemberRole.member,
  totalSlots: 10,
  filledSlots: 10,
  currentPeriodNo: 3,
  myPaymentStatus: PaymentStatus.paid,
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('shows the dues per period', (tester) async {
    // Act
    await tester.pumpApp(GroupCard(group: _group, onTap: () {}));

    // Assert
    expect(find.text('Arisan RT 05'), findsOneWidget);
    expect(find.text('Rp200.000 / bulan'), findsOneWidget);
    expect(find.text('Sudah bayar'), findsOneWidget);
  });

  testWidgets('shows the Pengurus chip for an organizer', (tester) async {
    // Arrange
    final group = _group.copyWith(myRole: MemberRole.organizer);

    // Act
    await tester.pumpApp(GroupCard(group: group, onTap: () {}));

    // Assert
    expect(find.text('Pengurus'), findsOneWidget);
  });

  testWidgets('a member sees no Pengurus chip', (tester) async {
    // Act
    await tester.pumpApp(GroupCard(group: _group, onTap: () {}));

    // Assert
    expect(find.text('Pengurus'), findsNothing);
  });

  testWidgets('shows the pending dot when proofs wait for review', (tester) async {
    // Arrange
    final group = _group.copyWith(myRole: MemberRole.organizer, pendingReviewCount: 2);

    // Act
    await tester.pumpApp(GroupCard(group: group, onTap: () {}));

    // Assert
    expect(find.byType(CountDot), findsOneWidget);
  });

  testWidgets('no pending dot without proofs to review', (tester) async {
    // Act
    await tester.pumpApp(GroupCard(group: _group, onTap: () {}));

    // Assert
    expect(find.byType(CountDot), findsNothing);
  });

  testWidgets('a weekly draft shows the fill ring and the Draf badge', (tester) async {
    // Arrange
    final group = _group.copyWith(
      status: GroupStatus.draft,
      periodType: PeriodType.weekly,
      filledSlots: 8,
      myPaymentStatus: null,
    );

    // Act
    await tester.pumpApp(GroupCard(group: group, onTap: () {}));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Rp200.000 / minggu'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
    expect(find.text('Draf'), findsOneWidget);
  });

  testWidgets('tapping the card calls onTap', (tester) async {
    // Arrange
    var taps = 0;
    await tester.pumpApp(GroupCard(group: _group, onTap: () => taps++));

    // Act
    await tester.tap(find.byType(GroupCard));

    // Assert
    expect(taps, 1);
  });

  testWidgets('the list card adds the slots, an upper-case PENGURUS and the draw date', (tester) async {
    // Arrange
    final group = _group.copyWith(myRole: MemberRole.organizer, nextDrawDate: DateTime.utc(2026, 10, 26));

    // Act
    await tester.pumpApp(GroupCard(group: group, layout: GroupCardLayout.list, onTap: () {}));

    // Assert
    expect(find.text('Rp200.000 / bulan · 10 slot'), findsOneWidget);
    expect(find.text('PENGURUS'), findsOneWidget);
    expect(find.textContaining('Kocok '), findsOneWidget);
  });

  testWidgets('the list card shows Persiapan for a group in setup', (tester) async {
    // Arrange
    final group = _group.copyWith(status: GroupStatus.draft, myPaymentStatus: null);

    // Act
    await tester.pumpApp(GroupCard(group: group, layout: GroupCardLayout.list, onTap: () {}));

    // Assert
    expect(find.text('Persiapan'), findsOneWidget);
  });
}

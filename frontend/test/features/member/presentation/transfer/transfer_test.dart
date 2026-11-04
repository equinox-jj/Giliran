import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/member/presentation/transfer_offer/page/transfer_offer_page.dart';
import 'package:giliran/features/member/presentation/transfer_respond/page/transfer_respond_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fake_group_repository.dart';
import '../../../../helpers/fake_member_repository.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late FakeMemberRepository members;
  late List<String> events;

  setUp(() {
    groups = FakeGroupRepository()
      ..group = const GroupDetail(
        id: 'g1',
        name: 'Arisan RT 05',
        status: GroupStatus.active,
        myRole: MemberRole.organizer,
        myMemberId: 'm1',
        organizer: UserSummary(id: 'u1', name: 'Rina Ayu'),
      );
    members = FakeMemberRepository()
      ..members = const [
        Member(
          id: 'm1',
          displayName: 'Rina Ayu',
          slotNo: 1,
          role: MemberRole.organizer,
          user: UserSummary(id: 'u1'),
        ),
        Member(
          id: 'm2',
          displayName: 'Pak Dedi',
          slotNo: 2,
          user: UserSummary(id: 'u2'),
        ),
        Member(id: 'm3', displayName: 'Bu Sri', slotNo: 3, isGuest: true),
      ];
    events = [];
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        memberRepositoryProvider.overrideWithValue(members),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(page, container: container);
    await tester.pumpAndSettle();
  }

  testWidgets('the offer lists members with an account, not guests or me', (tester) async {
    // Act
    await pump(tester, const TransferOfferPage(groupId: 'g1'));

    // Assert
    expect(find.text('Pak Dedi'), findsOneWidget);
    expect(find.text('Bu Sri'), findsNothing);
    expect(find.text('Rina Ayu'), findsNothing);
  });

  testWidgets('sending the offer confirms first, then shows it pending', (tester) async {
    // Arrange
    await pump(tester, const TransferOfferPage(groupId: 'g1'));
    await tester.tap(find.text('Pak Dedi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Kirim tawaran'));
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Kirim tawaran').last);
    await tester.pumpAndSettle();

    // Assert
    expect(members.lastTransferTarget, 'm2');
    expect(find.textContaining('Menunggu jawaban'), findsOneWidget);
  });

  testWidgets('accepting the role opens payment info', (tester) async {
    // Arrange
    await pump(
      tester,
      TransferRespondPage(
        groupId: 'g1',
        transferId: 't1',
        onAccepted: () => events.add('paymentInfo'),
        onDone: () => events.add('done'),
      ),
    );

    // Act
    await tester.scrollUntilVisible(find.text('Terima'), 200);
    await tester.tap(find.text('Terima'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Rina Ayu ingin kamu jadi pengurus Arisan RT 05', findRichText: true), findsOneWidget);
    expect(members.calls, ['acceptTransfer']);
    expect(events, ['paymentInfo']);
  });

  testWidgets('declining goes back', (tester) async {
    // Arrange
    await pump(
      tester,
      TransferRespondPage(
        groupId: 'g1',
        transferId: 't1',
        onAccepted: () => events.add('paymentInfo'),
        onDone: () => events.add('done'),
      ),
    );

    // Act
    await tester.scrollUntilVisible(find.text('Tolak'), 200);
    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();

    // Assert
    expect(members.calls, ['declineTransfer']);
    expect(events, ['done']);
  });
}

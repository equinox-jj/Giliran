import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/services/share_service.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/member/presentation/invite/page/invite_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/clipboard.dart';
import '../../../../helpers/fake_group_repository.dart';
import '../../../../helpers/fake_member_repository.dart';
import '../../../../helpers/fake_share_service.dart';
import '../../../../helpers/pump_app.dart';

const _url = 'https://giliran.monai.my.id/j/K7P2QX9M';

GroupDetail _group({int filled = 8}) => GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  totalSlots: 10,
  filledSlots: filled,
  status: GroupStatus.draft,
  myRole: MemberRole.organizer,
  invite: const Invite(code: 'K7P2QX9M', url: _url),
);

void main() {
  late FakeGroupRepository groups;
  late FakeMemberRepository members;
  late FakeShareService share;

  setUp(() {
    groups = FakeGroupRepository();
    members = FakeMemberRepository()
      ..members = const [
        Member(id: 'm1', displayName: 'Rina Ayu', slotNo: 1, role: MemberRole.organizer),
        Member(id: 'm2', displayName: 'Pak Dedi', slotNo: 2, isGuest: true),
      ];
    share = FakeShareService();
  });

  Future<void> pumpInvite(WidgetTester tester, GroupDetail group) async {
    groups
      ..group = group
      ..groupResult = null;
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        memberRepositoryProvider.overrideWithValue(members),
        shareServiceProvider.overrideWithValue(share),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(const InvitePage(groupId: 'g1'), container: container);
    await tester.pumpAndSettle();
  }

  testWidgets('the headline counts the open slots', (tester) async {
    // Act
    await pumpInvite(tester, _group());

    // Assert
    expect(find.text('Undang 2 orang lagi', findRichText: true), findsOneWidget);
  });

  testWidgets('the QR encodes the invite link', (tester) async {
    // Act
    await pumpInvite(tester, _group());

    // Assert
    expect(find.byKey(const ValueKey('qr:$_url')), findsOneWidget);
  });

  testWidgets('the code shows grouped and copies without spaces', (tester) async {
    // Arrange
    final copied = captureClipboard(tester);
    await pumpInvite(tester, _group());

    // Act
    await tester.tap(find.bySemanticsLabel('Salin kode undangan'));
    await tester.pump();

    // Assert
    expect(find.text('K7P2 QX9M'), findsOneWidget);
    expect(copied, ['K7P2QX9M']);
  });

  testWidgets('Bagikan ke WhatsApp sends the link in the message', (tester) async {
    // Arrange
    await pumpInvite(tester, _group());

    // Act
    await tester.tap(find.text('Bagikan ke WhatsApp'));
    await tester.pump();

    // Assert
    expect(share.whatsApp.single.text, contains(_url));
    expect(share.whatsApp.single.phone, isNull);
  });

  testWidgets('Buat link baru asks first, then resets the code', (tester) async {
    // Arrange
    await pumpInvite(tester, _group());
    await tester.tap(find.byType(OverflowMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat link baru'));
    await tester.pumpAndSettle();
    final asked = find.text('Buat link baru? Link lama tidak bisa dipakai lagi.').evaluate().isNotEmpty;

    // Act
    await tester.tap(find.text('Buat link baru').last);
    await tester.pumpAndSettle();

    // Assert
    expect(asked, isTrue);
    expect(members.calls, contains('resetInviteCode'));
  });

  testWidgets('a full group says so and makes sharing secondary', (tester) async {
    // Act
    await pumpInvite(tester, _group(filled: 10));

    // Assert
    expect(find.text('Semua slot terisi', findRichText: true), findsNWidgets(2));
    final share = tester.widget<AppButton>(find.widgetWithText(AppButton, 'Bagikan ke WhatsApp'));
    expect(share.variant, AppButtonVariant.secondary);
  });

  testWidgets('the slot list shows members and dashed empty slots', (tester) async {
    // Act
    await pumpInvite(tester, _group());
    await tester.scrollUntilVisible(find.text('Pak Dedi'), 200);

    // Assert
    expect(find.text('Pak Dedi'), findsOneWidget);
    expect(find.text('Slot kosong'), findsWidgets);
  });
}

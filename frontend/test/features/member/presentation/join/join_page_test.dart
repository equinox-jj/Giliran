import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/period_type.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/domain/entities/invite_preview.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/member/presentation/join/page/join_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/failures.dart';
import '../../../../helpers/fake_member_repository.dart';
import '../../../../helpers/pump_app.dart';

InvitePreview _preview({bool canJoin = true, bool alreadyMember = false, int filled = 8}) => InvitePreview(
  groupId: 'g1',
  groupName: 'Arisan RT 05',
  organizer: const UserSummary(id: 'u1', name: 'Rina Ayu'),
  amount: 200000,
  periodType: PeriodType.monthly,
  totalSlots: 10,
  filledSlots: filled,
  startDate: DateTime.utc(2026, 11, 25),
  status: GroupStatus.draft,
  canJoin: canJoin,
  alreadyMember: alreadyMember,
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeMemberRepository members;
  late List<String> opened;

  setUp(() {
    members = FakeMemberRepository();
    opened = [];
  });

  Future<void> pumpJoin(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [memberRepositoryProvider.overrideWithValue(members)]);
    addTearDown(container.dispose);
    await tester.pumpPage(
      JoinPage(code: 'K7P2QX9M', onOpenGroup: (id) => opened.add(id), onLater: () => opened.add('later')),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows who invites and the group terms', (tester) async {
    // Arrange
    members.previewResult = Right(_preview());

    // Act
    await pumpJoin(tester);

    // Assert
    expect(find.text('Rina Ayu mengajak kamu ke Arisan RT 05', findRichText: true), findsOneWidget);
    expect(find.text('Rp200.000 / bulan'), findsOneWidget);
    expect(find.text('8 dari 10 terisi'), findsOneWidget);
  });

  testWidgets('joining opens the group', (tester) async {
    // Arrange
    members
      ..previewResult = Right(_preview())
      ..memberResult = const Right(Member(id: 'm9', groupId: 'g1'));
    await pumpJoin(tester);

    // Act
    await tester.scrollUntilVisible(find.text('Gabung'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Gabung'));
    await tester.pumpAndSettle();

    // Assert
    expect(members.calls, contains('joinGroup:K7P2QX9M'));
    expect(opened, ['g1']);
  });

  testWidgets('an existing member gets Buka grup', (tester) async {
    // Arrange
    members.previewResult = Right(_preview(alreadyMember: true, canJoin: false));
    await pumpJoin(tester);

    // Act
    await tester.scrollUntilVisible(find.text('Buka grup'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Buka grup'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Gabung'), findsNothing);
    expect(opened, ['g1']);
  });

  testWidgets('a group that cannot be joined shows a banner and a disabled button', (tester) async {
    // Arrange
    members.previewResult = Right(_preview(canJoin: false, filled: 10));

    // Act
    await pumpJoin(tester);
    await tester.scrollUntilVisible(find.text('Gabung'), 200, scrollable: find.byType(Scrollable).first);

    // Assert
    expect(find.byType(AppBanner), findsOneWidget);
    expect(tester.widget<AppButton>(find.widgetWithText(AppButton, 'Gabung')).onPressed, isNull);
  });

  testWidgets('invite_not_found shows the invalid link state', (tester) async {
    // Arrange
    members.previewResult = Left(notFound(ApiErrorCode.inviteNotFound));

    // Act
    await pumpJoin(tester);

    // Assert
    expect(find.text('Link undangan tidak berlaku. Minta link baru ke pengurus.'), findsOneWidget);
  });
}

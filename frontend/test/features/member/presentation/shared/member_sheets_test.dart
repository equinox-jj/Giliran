import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/services/share_service.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/domain/entities/claim_link.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/member/domain/usecases/parse_invite_code_usecase.dart';
import 'package:giliran/features/member/presentation/shared/widgets/claim_link_sheet.dart';
import 'package:giliran/features/member/presentation/shared/widgets/guest_sheet.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/failures.dart';
import '../../../../helpers/fake_member_repository.dart';
import '../../../../helpers/fake_share_service.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeMemberRepository members;
  late FakeShareService share;

  setUp(() {
    members = FakeMemberRepository();
    share = FakeShareService();
  });

  Future<void> pumpSheet(WidgetTester tester, Widget sheet) async {
    final container = ProviderContainer(
      overrides: [
        memberRepositoryProvider.overrideWithValue(members),
        shareServiceProvider.overrideWithValue(share),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(Scaffold(body: sheet), container: container);
    await tester.pumpAndSettle();
  }

  group('GuestSheet', () {
    testWidgets('the button names the slot the guest takes', (tester) async {
      // Act
      await pumpSheet(tester, const GuestSheet(groupId: 'g1', slotNo: 9));

      // Assert
      expect(find.text('Tambahkan ke slot 09'), findsOneWidget);
    });

    testWidgets('group_full disables the button and says why', (tester) async {
      // Arrange
      members.memberResult = Left(conflict(ApiErrorCode.groupFull));
      await pumpSheet(tester, const GuestSheet(groupId: 'g1', slotNo: 9));
      await tester.enterText(find.byType(TextField).first, 'Bu Sri');

      // Act
      await tester.tap(find.text('Tambahkan ke slot 09'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Semua slot sudah terisi.'), findsOneWidget);
      expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);
    });

    testWidgets('a one-letter name is flagged before any request', (tester) async {
      // Arrange
      await pumpSheet(tester, const GuestSheet(groupId: 'g1', slotNo: 9));
      await tester.enterText(find.byType(TextField).first, 'S');

      // Act
      await tester.tap(find.text('Tambahkan ke slot 09'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Nama 2–50 huruf.'), findsOneWidget);
      expect(members.calls, isEmpty);
    });
  });

  group('ClaimLinkSheet', () {
    final link = ClaimLink(url: 'https://giliran.monai.my.id/c/${'a' * 32}', expiresAt: DateTime.utc(2026, 11, 11, 3));

    testWidgets('Kirim lewat WhatsApp goes to the guest phone', (tester) async {
      // Arrange
      await pumpSheet(
        tester,
        ClaimLinkSheet(
          guest: const Member(id: 'm5', displayName: 'Bu Sri', isGuest: true, guestPhone: '+6281234567890'),
          link: link,
          groupName: 'Arisan RT 05',
        ),
      );

      // Act
      await tester.tap(find.text('Kirim lewat WhatsApp'));
      await tester.pump();

      // Assert
      expect(share.whatsApp.single.phone, '+6281234567890');
      expect(share.whatsApp.single.text, contains(link.url));
      expect(find.text('Biar Bu Sri pakai aplikasi'), findsOneWidget);
    });
  });

  group('ParseInviteCodeUseCase', () {
    const parse = ParseInviteCodeUseCase();

    test('reads the code from an invite link', () {
      // Act
      final code = parse('https://giliran.monai.my.id/j/K7P2QX9M');

      // Assert
      expect(code, 'K7P2QX9M');
    });

    test('accepts a typed code with spaces and lower case', () {
      // Act
      final code = parse('k7p2 qx9m');

      // Assert
      expect(code, 'K7P2QX9M');
    });

    test('rejects anything else', () {
      // Act
      final codes = [parse('hello'), parse('https://example.com/x'), parse('K7P2QX9')];

      // Assert
      expect(codes, everyElement(isNull));
    });
  });
}

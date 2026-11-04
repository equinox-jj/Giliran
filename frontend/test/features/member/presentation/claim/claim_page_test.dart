import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/presentation/claim/page/claim_page.dart';

import '../../../../helpers/failures.dart';
import '../../../../helpers/fake_member_repository.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  late FakeMemberRepository members;
  late List<String?> claimed;

  setUp(() {
    members = FakeMemberRepository();
    claimed = [];
  });

  Future<void> pumpClaim(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [memberRepositoryProvider.overrideWithValue(members)]);
    addTearDown(container.dispose);
    await tester.pumpPage(
      ClaimPage(token: 'a' * 32, onClaimed: claimed.add, onClose: () {}),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Ini saya, ambil slot claims and opens the group', (tester) async {
    // Arrange
    members.claimResult = const Right('g1');
    await pumpClaim(tester);

    // Act
    await tester.tap(find.text('Ini saya, ambil slot'));
    await tester.pumpAndSettle();

    // Assert
    expect(members.calls, ['claimSlot']);
    expect(claimed, ['g1']);
  });

  testWidgets('claim_not_found shows the expired link state', (tester) async {
    // Arrange
    members.claimResult = Left(notFound(ApiErrorCode.claimNotFound));
    await pumpClaim(tester);

    // Act
    await tester.tap(find.text('Ini saya, ambil slot'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Link klaim tidak berlaku'), findsOneWidget);
  });

  testWidgets('already_member explains and offers Buka grup', (tester) async {
    // Arrange
    members.claimResult = Left(conflict(ApiErrorCode.alreadyMember));
    await pumpClaim(tester);
    await tester.tap(find.text('Ini saya, ambil slot'));
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.text('Buka grup'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Kamu sudah jadi anggota grup ini.'), findsOneWidget);
    expect(claimed, [null]);
  });
}

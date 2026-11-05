import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/connectivity_controller.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:giliran/features/payment/domain/entities/payment.dart';
import 'package:giliran/features/payment/presentation/proof_review/page/proof_review_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/a11y.dart';
import '../../../../helpers/failures.dart';
import '../../../../helpers/fake_connectivity.dart';
import '../../../../helpers/fake_group_repository.dart';
import '../../../../helpers/fake_payment_repository.dart';
import '../../../../helpers/pump_app.dart';

Payment _pending(String id, int slot, String name) => Payment(
  id: id,
  periodId: 'p1',
  member: MemberRef(id: 'm$slot', displayName: name, slotNo: slot),
  amount: 200000,
  status: PaymentStatus.pendingReview,
  updatedAt: DateTime.utc(2026, 11, 3, 12, 2),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late FakePaymentRepository payments;
  late int closed;

  setUp(() {
    groups = FakeGroupRepository()
      ..group = const GroupDetail(
        id: 'g1',
        name: 'Arisan RT 05',
        status: GroupStatus.active,
        myRole: MemberRole.organizer,
      )
      ..groupResult = null;
    payments = FakePaymentRepository()
      ..payments = [_pending('pay1', 2, 'Pak Dedi'), _pending('pay2', 5, 'Bu Sri')]
      ..paymentResult = Right(_pending('pay1', 2, 'Pak Dedi').copyWith(status: PaymentStatus.paid));
    closed = 0;
  });

  Future<void> pumpReview(
    WidgetTester tester, {
    bool online = true,
    String paymentId = 'pay1',
    Size size = const Size(390, 844),
  }) async {
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        paymentRepositoryProvider.overrideWithValue(payments),
        connectivityControllerProvider.overrideWith(() => FakeConnectivityController(online)),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      ProofReviewPage(groupId: 'g1', paymentId: paymentId, onClose: () => closed++),
      container: container,
      size: size,
    );
    await tester.pumpAndSettle();
  }

  Future<void> approve(WidgetTester tester) async {
    // Let an earlier toast expire so it doesn't cover the bottom buttons.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Setujui'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Setujui').last);
    await tester.pumpAndSettle();
  }

  testWidgets('fits a 360 dp phone at 130 percent text and meets the a11y guidelines', (tester) async {
    // Arrange
    final semantics = tester.ensureSemantics();
    useLargeText(tester);

    // Act
    await pumpReview(tester, size: a11yPhone);

    // Assert
    await expectAccessibleScreen(tester);
    semantics.dispose();
  });

  testWidgets('approve asks for confirmation first', (tester) async {
    // Arrange
    await pumpReview(tester);

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Setujui'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Setujui pembayaran Pak Dedi?'), findsOneWidget);
    expect(payments.calls, isNot(contains('approvePayment')));
  });

  testWidgets('approve retry reuses the idempotency key', (tester) async {
    // Arrange
    payments.writeResults.add(const Left(Failure.timeout()));
    await pumpReview(tester);
    await approve(tester);

    // Act
    await approve(tester);

    // Assert
    expect(payments.calls.where((c) => c == 'approvePayment'), hasLength(2));
    expect(payments.keys, hasLength(2));
    expect(payments.keys.first, payments.keys.last);
  });

  testWidgets('a new approval after success gets a new key and moves on', (tester) async {
    // Arrange
    await pumpReview(tester);
    await approve(tester);
    payments.paymentResult = Right(_pending('pay2', 5, 'Bu Sri').copyWith(status: PaymentStatus.paid));

    // Act
    await approve(tester);

    // Assert
    expect(payments.keys.toSet(), hasLength(2));
    expect(closed, 1);
  });

  testWidgets('swiping shows the next pending proof with the counter', (tester) async {
    // Arrange
    await pumpReview(tester);
    expect(find.text('1 dari 2 menunggu'), findsOneWidget);

    // Act
    await tester.fling(find.byType(ImageViewer), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('2 dari 2 menunggu'), findsOneWidget);
    expect(find.text('Bu Sri'), findsWidgets);
  });

  testWidgets('reject offers quick-pick reasons and sends the chosen one', (tester) async {
    // Arrange
    await pumpReview(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Tolak'));
    await tester.pumpAndSettle();
    expect(find.text('Nominal kurang'), findsOneWidget);
    expect(find.text('Bukti tidak jelas'), findsOneWidget);
    expect(find.text('Bukan transfer ke rekening ini'), findsOneWidget);
    expect(find.text('Tanggal tidak sesuai'), findsOneWidget);

    // Act
    await tester.tap(find.text('Bukti tidak jelas'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Tolak bukti'));
    await tester.pumpAndSettle();

    // Assert
    expect(payments.lastReason, 'Bukti tidak jelas');
  });

  testWidgets('reject needs a reason of at least 3 characters', (tester) async {
    // Arrange
    await pumpReview(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Tolak'));
    await tester.pumpAndSettle();

    // Act
    await tester.enterText(find.byType(TextField), 'ok');
    await tester.pumpAndSettle();

    // Assert
    expect(tester.widget<AppButton>(find.widgetWithText(AppButton, 'Tolak bukti')).onPressed, isNull);
    expect(find.text('Alasan 3–500 karakter.'), findsWidgets);
  });

  testWidgets('payment_already_reviewed tells the organizer and reloads', (tester) async {
    // Arrange
    payments.writeResults.add(Left(conflict(ApiErrorCode.paymentAlreadyReviewed)));
    await pumpReview(tester);
    final loadsBefore = payments.calls.where((c) => c == 'getPaymentDetail:pay1').length;

    // Act
    await approve(tester);

    // Assert
    expect(find.text('Sudah dicek pengurus lain'), findsOneWidget);
    expect(payments.calls.where((c) => c == 'getPaymentDetail:pay1').length, loadsBefore + 1);
  });

  testWidgets('offline, approve and reject say they need a connection', (tester) async {
    // Act
    await pumpReview(tester, online: false);

    // Assert
    expect(tester.widget<AppButton>(find.widgetWithText(AppButton, 'Setujui')).onPressed, isNull);
    expect(tester.widget<AppButton>(find.widgetWithText(AppButton, 'Tolak')).onPressed, isNull);
    expect(find.text('Butuh koneksi internet.'), findsWidgets);
  });

  testWidgets('a member viewing their own proof gets no review actions', (tester) async {
    // Arrange
    groups.group = groups.group!.copyWith(myRole: MemberRole.member);

    // Act
    await pumpReview(tester);

    // Assert
    expect(find.widgetWithText(AppButton, 'Setujui'), findsNothing);
    expect(find.text('1 dari 2 menunggu'), findsNothing);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/connectivity_controller.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/draw_method.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/period_status.dart';
import 'package:giliran/features/draw/data/repositories/draw_repository_impl.dart';
import 'package:giliran/features/draw/presentation/draw_stage/page/draw_stage_page.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:giliran/features/payment/domain/entities/period.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fake_connectivity.dart';
import '../../../../helpers/fake_draw_repository.dart';
import '../../../../helpers/fake_group_repository.dart';
import '../../../../helpers/fake_member_repository.dart';
import '../../../../helpers/fake_payment_repository.dart';
import '../../../../helpers/pump_app.dart';
import '../../fixtures.dart';

final _drawDate = DateTime.utc(2026, 10, 26);

/// 19.30 Jakarta on the draw date.
final _onDrawDay = DateTime.utc(2026, 10, 26, 12, 30);

const _organizer = GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  status: GroupStatus.active,
  myRole: MemberRole.organizer,
  drawMethod: DrawMethod.random,
  totalSlots: 10,
);

final _drawButton = find.byWidgetPredicate((w) => w is CircleIconButton && w.variant == CircleIconButtonVariant.draw);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late FakePaymentRepository payments;
  late FakeMemberRepository members;
  late FakeDrawRepository draws;
  late List<bool> drawn;

  setUp(() {
    groups = FakeGroupRepository()
      ..group = _organizer
      ..groupResult = null;
    payments = FakePaymentRepository()
      ..periods = [Period(id: 'p1', periodNo: 4, status: PeriodStatus.open, drawDate: _drawDate)];
    members = FakeMemberRepository()
      ..members = [
        for (var n = 1; n <= 10; n++)
          Member(id: 'm$n', slotNo: n, displayName: 'Anggota $n', hasWon: n <= 2, fixedOrderPosition: 11 - n),
      ];
    draws = FakeDrawRepository()
      ..drawResult = const Right(committedDraw)
      ..runResult = Right(drawnDraw);
    drawn = [];
  });

  /// The orbit animates forever, so settle with timed pumps.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpStage(WidgetTester tester, {bool online = true, DateTime? now, bool reduced = false}) async {
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        paymentRepositoryProvider.overrideWithValue(payments),
        memberRepositoryProvider.overrideWithValue(members),
        drawRepositoryProvider.overrideWithValue(draws),
        connectivityControllerProvider.overrideWith(() => FakeConnectivityController(online)),
        clockProvider.overrideWithValue(() => now ?? _onDrawDay),
      ],
    );
    addTearDown(container.dispose);
    final page = DrawStagePage(groupId: 'g1', periodId: 'p1', onDrawn: drawn.add, onClose: () {});
    await tester.pumpPage(
      reduced ? MediaQuery(data: const MediaQueryData(disableAnimations: true), child: page) : page,
      container: container,
    );
    await settle(tester);
  }

  Future<void> tapDraw(WidgetTester tester) async {
    await tester.ensureVisible(_drawButton);
    await tester.tap(_drawButton);
    await settle(tester);
  }

  testWidgets('shows the headline, the eligible count and the commitment', (tester) async {
    // Arrange
    await pumpStage(tester);

    // Assert
    expect(find.textContaining('Kocokan'), findsOneWidget);
    expect(find.text('8 peserta belum dapat'), findsOneWidget);
    expect(find.text('Kode komitmen 6668…2925'), findsOneWidget);
  });

  testWidgets('the commitment line opens the full hash', (tester) async {
    // Arrange
    await pumpStage(tester);

    // Act
    await tester.tap(find.text('Kode komitmen 6668…2925'));
    await settle(tester);

    // Assert
    expect(find.text(goldenSeedHash), findsOneWidget);
  });

  testWidgets('Kocok is disabled before the draw date with the date', (tester) async {
    // Arrange
    await pumpStage(tester, now: DateTime.utc(2026, 10, 24, 5));

    // Act
    final button = tester.widget<CircleIconButton>(_drawButton);

    // Assert
    expect(button.onPressed, isNull);
    expect(find.text('Bisa dikocok Sen, 26 Okt'), findsOneWidget);
  });

  testWidgets('members see no button and the caption', (tester) async {
    // Arrange
    groups.group = _organizer.copyWith(myRole: MemberRole.member);
    await pumpStage(tester);

    // Assert
    expect(_drawButton, findsNothing);
    expect(find.text('Pengurus akan mengocok. Kamu dapat notifikasi hasilnya.'), findsOneWidget);
  });

  testWidgets('offline disables the draw with the reason', (tester) async {
    // Arrange
    await pumpStage(tester, online: false);

    // Assert
    expect(tester.widget<CircleIconButton>(_drawButton).onPressed, isNull);
    expect(find.text('Butuh koneksi internet.'), findsOneWidget);
  });

  testWidgets('fixed order shows the next person, "Tetapkan giliran" and no seed line', (tester) async {
    // Arrange
    groups.group = _organizer.copyWith(drawMethod: DrawMethod.fixedOrder);
    draws.drawResult = Right(committedDraw.copyWith(method: DrawMethod.fixedOrder, seedHash: null));
    await pumpStage(tester);

    // Assert
    expect(find.text('Giliran berikutnya'), findsOneWidget);
    // Lowest unwon position: slot 10 has position 1.
    expect(find.text('Anggota 10'), findsOneWidget);
    expect(find.text('Tetapkan giliran'), findsOneWidget);
    expect(find.textContaining('Kode komitmen'), findsNothing);
  });

  testWidgets('a successful draw leaves with the reveal', (tester) async {
    // Arrange
    await pumpStage(tester);

    // Act
    await tapDraw(tester);

    // Assert
    expect(draws.calls, contains('runDraw'));
    expect(drawn, [true]);
  });

  testWidgets('incomplete payments ask first, then resend confirmed with the same key', (tester) async {
    // Arrange
    draws.runResults.add(
      const Left(
        Failure.conflict(code: ApiErrorCode.paymentsIncomplete, extensions: {'paid_count': 8, 'total_count': 10}),
      ),
    );
    await pumpStage(tester);

    // Act
    await tapDraw(tester);
    final asked = find.text('8 dari 10 sudah bayar. Tetap kocok?').evaluate().isNotEmpty;
    await tester.tap(find.text('Saya tetap mau mengocok'));
    await settle(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Kocok sekarang'));
    await settle(tester);

    // Assert
    expect(asked, isTrue);
    expect(draws.confirms, [false, true]);
    expect(draws.keys.toSet(), hasLength(1));
    expect(drawn, [true]);
  });

  testWidgets('the confirm button waits for the check row', (tester) async {
    // Arrange
    draws.runResults.add(
      const Left(
        Failure.conflict(code: ApiErrorCode.paymentsIncomplete, extensions: {'paid_count': 8, 'total_count': 10}),
      ),
    );
    await pumpStage(tester);

    // Act
    await tapDraw(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Kocok sekarang'));
    await settle(tester);

    // Assert
    expect(draws.confirms, [false]);
  });

  testWidgets('draw_already_done goes to the result without the reveal', (tester) async {
    // Arrange
    draws.runResult = const Left(Failure.conflict(code: ApiErrorCode.drawAlreadyDone));
    await pumpStage(tester);

    // Act
    await tapDraw(tester);

    // Assert
    expect(drawn, [false]);
  });

  testWidgets('opening a drawn period goes straight to the result', (tester) async {
    // Arrange
    draws.drawResult = Right(drawnDraw);

    // Act
    await pumpStage(tester);

    // Assert
    expect(drawn, [false]);
    expect(draws.calls, isNot(contains('runDraw')));
  });

  testWidgets('reduced motion shows a static grid', (tester) async {
    // Arrange
    await pumpStage(tester, reduced: true);

    // Act
    await tester.pumpAndSettle();

    // Assert
    expect(find.descendant(of: find.byType(DrawStage), matching: find.byType(Wrap)), findsOneWidget);
  });
}

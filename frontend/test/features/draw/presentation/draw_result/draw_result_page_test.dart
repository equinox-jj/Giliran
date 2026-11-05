import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/network/connectivity_controller.dart';
import 'package:giliran/core/services/share_service.dart';
import 'package:giliran/core/services/widget_image_exporter.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/period_status.dart';
import 'package:giliran/features/draw/data/repositories/draw_repository_impl.dart';
import 'package:giliran/features/draw/presentation/draw_result/page/draw_result_page.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:giliran/features/payment/domain/entities/period.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/a11y.dart';
import '../../../../helpers/clipboard.dart';
import '../../../../helpers/fake_connectivity.dart';
import '../../../../helpers/fake_draw_repository.dart';
import '../../../../helpers/fake_group_repository.dart';
import '../../../../helpers/fake_member_repository.dart';
import '../../../../helpers/fake_payment_repository.dart';
import '../../../../helpers/fake_share_service.dart';
import '../../../../helpers/fake_widget_image_exporter.dart';
import '../../../../helpers/pump_app.dart';
import '../../fixtures.dart';

const _group = GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  status: GroupStatus.active,
  myRole: MemberRole.organizer,
  myMemberId: 'm1',
  amount: 200000,
  totalSlots: 10,
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late FakePaymentRepository payments;
  late FakeMemberRepository members;
  late FakeDrawRepository draws;
  late FakeShareService share;
  late FakeWidgetImageExporter exporter;
  late int payouts;

  setUp(() {
    groups = FakeGroupRepository()
      ..group = _group
      ..groupResult = null;
    payments = FakePaymentRepository()..periods = [const Period(id: 'p1', periodNo: 4, status: PeriodStatus.drawn)];
    members = FakeMemberRepository()
      ..members = [
        for (var n = 1; n <= 10; n++) Member(id: 'm$n', slotId: goldenSlotId(n), slotNo: n, displayName: 'Anggota $n'),
      ];
    draws = FakeDrawRepository()..drawResult = Right(drawnDraw);
    share = FakeShareService();
    exporter = FakeWidgetImageExporter();
    payouts = 0;
  });

  Future<void> pumpResult(
    WidgetTester tester, {
    bool reveal = false,
    // Tall enough that the cards below the ticket are built.
    Size size = const Size(390, 1800),
  }) async {
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        paymentRepositoryProvider.overrideWithValue(payments),
        memberRepositoryProvider.overrideWithValue(members),
        drawRepositoryProvider.overrideWithValue(draws),
        shareServiceProvider.overrideWithValue(share),
        widgetImageExporterProvider.overrideWithValue(exporter),
        connectivityControllerProvider.overrideWith(() => FakeConnectivityController(true)),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 26, 13)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      DrawResultPage(groupId: 'g1', periodId: 'p1', reveal: reveal, onPayout: () => payouts++, onClose: () {}),
      container: container,
      size: size,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openVerify(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Cek keasliannya'));
    await tester.tap(find.text('Cek keasliannya'));
    await tester.pumpAndSettle();
  }

  testWidgets('fits a 360 dp phone at 130 percent text and meets the a11y guidelines', (tester) async {
    // Arrange
    final semantics = tester.ensureSemantics();
    useLargeText(tester);

    // Act
    await pumpResult(tester, size: a11yPhone);

    // Assert
    await expectAccessibleScreen(tester);
    semantics.dispose();
  });

  testWidgets('shows the winner headline and the ticket', (tester) async {
    // Arrange
    await pumpResult(tester);

    // Assert
    expect(find.textContaining('Agus dapat giliran periode 4!', findRichText: true), findsOneWidget);
    expect(find.text('No. 05'), findsOneWidget);
    expect(find.text('P4 / 10'), findsOneWidget);
    expect(find.text('7H2K 9QX4 MP'), findsOneWidget);
    expect(find.text('8/10 sudah bayar saat dikocok'), findsOneWidget);
  });

  testWidgets("the winner's own view", (tester) async {
    // Arrange
    groups.group = _group.copyWith(myRole: MemberRole.member, myMemberId: 'm5');
    await pumpResult(tester);

    // Assert
    expect(find.textContaining('kamu dapat giliran!', findRichText: true), findsOneWidget);
    expect(find.text('Pengurus akan menyerahkan uangnya. Konfirmasi setelah kamu terima.'), findsOneWidget);
    expect(find.textContaining('Serahkan'), findsNothing);
  });

  testWidgets('organizers hand over the pot from the next-step card', (tester) async {
    // Arrange
    await pumpResult(tester);

    // Act
    await tester.ensureVisible(find.text('Serahkan Rp2.000.000 ke Agus'));
    await tester.tap(find.text('Serahkan Rp2.000.000 ke Agus'));
    await tester.pumpAndSettle();

    // Assert
    expect(payouts, 1);
  });

  testWidgets('the reveal plays with a heavy haptic', (tester) async {
    // Arrange
    final haptics = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String?);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    // Act
    await pumpResult(tester, reveal: true);

    // Assert
    expect(haptics, contains('HapticFeedbackType.heavyImpact'));
    expect(find.text('No. 05'), findsOneWidget);
  });

  testWidgets('verify sheet says "Cocok" when the device check passes', (tester) async {
    // Arrange
    await pumpResult(tester);

    // Act
    await openVerify(tester);

    // Assert
    expect(find.text('Cocok ✓ — hasil ini tidak diubah setelah kode dipublikasikan'), findsOneWidget);
    expect(find.text('Laporkan'), findsNothing);
    expect(find.text(goldenSeed), findsOneWidget);
  });

  testWidgets('verify sheet says "Tidak cocok" with a report link for a tampered draw', (tester) async {
    // Arrange
    draws.drawResult = Right(drawnDraw.copyWith(winner: drawSlot(6)));
    await pumpResult(tester);

    // Act
    await openVerify(tester);
    await tester.tap(find.text('Laporkan'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Tidak cocok'), findsOneWidget);
    expect(share.openedUrls.single.scheme, 'mailto');
    expect(share.openedUrls.single.queryParameters['subject'], contains('7H2K9QX4MP'));
  });

  testWidgets('copy buttons copy the raw values', (tester) async {
    // Arrange
    final copied = captureClipboard(tester);
    await pumpResult(tester);
    await openVerify(tester);

    // Act
    await tester.tap(find.text('Salin').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salin').last);
    await tester.tap(find.text('Salin').last);
    await tester.pumpAndSettle();

    // Assert
    expect(copied, [goldenSeedHash, goldenSeed]);
  });

  testWidgets('share exports the ticket at 1080 × 1350 with the verify link', (tester) async {
    // Arrange
    await pumpResult(tester);

    // Act
    await tester.ensureVisible(find.text('Bagikan ke WhatsApp'));
    await tester.tap(find.text('Bagikan ke WhatsApp'));
    await tester.pumpAndSettle();

    // Assert
    final export = exporter.exports.single;
    expect(export.logicalSize * export.pixelRatio, const Size(1080, 1350));
    expect(share.sharedImages.single.text, contains('https://giliran.monai.my.id/v/7H2K9QX4MP'));
  });

  testWidgets('save image shares the image without text', (tester) async {
    // Arrange
    await pumpResult(tester);

    // Act
    await tester.ensureVisible(find.text('Simpan gambar'));
    await tester.tap(find.text('Simpan gambar'));
    await tester.pumpAndSettle();

    // Assert
    expect(share.sharedImages.single.text, isNull);
  });
}

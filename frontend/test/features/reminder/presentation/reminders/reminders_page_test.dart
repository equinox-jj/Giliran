import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/connectivity_controller.dart';
import 'package:giliran/core/services/share_service.dart';
import 'package:giliran/core/services/widget_image_exporter.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/reminder_skip_reason.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/reminder/data/repositories/reminder_repository_impl.dart';
import 'package:giliran/features/reminder/domain/entities/recap.dart';
import 'package:giliran/features/reminder/domain/entities/reminder_result.dart';
import 'package:giliran/features/reminder/presentation/reminders/page/reminders_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fake_connectivity.dart';
import '../../../../helpers/fake_group_repository.dart';
import '../../../../helpers/fake_reminder_repository.dart';
import '../../../../helpers/fake_share_service.dart';
import '../../../../helpers/fake_widget_image_exporter.dart';
import '../../../../helpers/pump_app.dart';

const _dedi = MemberRef(id: 'm4', displayName: 'Pak Dedi', slotNo: 4, isGuest: false);
const _ani = MemberRef(id: 'm7', displayName: 'Bu Ani', slotNo: 7, isGuest: true);
const _joko = MemberRef(id: 'm9', displayName: 'Pak Joko', slotNo: 9, isGuest: false);

final _recap = Recap(
  groupName: 'Arisan RT 05',
  periodNo: 4,
  totalPeriods: 10,
  dueDate: DateTime.utc(2026, 10, 24),
  drawDate: DateTime.utc(2026, 10, 25),
  amount: 200000,
  paidCount: 7,
  totalCount: 10,
  collectedAmount: 1400000,
  expectedAmount: 2000000,
  unpaid: const [
    RecapUnpaid(member: _dedi, whatsappPhone: '+6281234567890'),
    RecapUnpaid(member: _ani, whatsappPhone: '+6285600001111'),
    RecapUnpaid(member: _joko),
  ],
  paymentInfo: const PaymentInfo(bankName: 'BCA', accountNumber: '1234567890', accountHolder: 'Rina'),
);

Finder _whatsAppFor(String name) => find.byWidgetPredicate(
  (w) => w is CircleIconButton && w.semanticLabel == 'Ingatkan $name lewat WhatsApp',
);

final _sendButton = find.byWidgetPredicate((w) => w is AppButton && w.label.startsWith('Kirim notifikasi'));

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late FakeReminderRepository reminders;
  late FakeShareService share;
  late FakeWidgetImageExporter exporter;

  setUp(() {
    groups = FakeGroupRepository()..groupResult = const Right(GroupDetail(id: 'g1', currentPeriodId: 'p4'));
    reminders = FakeReminderRepository()..recapResult = Right(_recap);
    share = FakeShareService();
    exporter = FakeWidgetImageExporter();
  });

  Future<void> pumpReminders(WidgetTester tester, {bool online = true, bool settle = true}) async {
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        reminderRepositoryProvider.overrideWithValue(reminders),
        shareServiceProvider.overrideWithValue(share),
        widgetImageExporterProvider.overrideWithValue(exporter),
        connectivityControllerProvider.overrideWith(() => FakeConnectivityController(online)),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 20, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      RemindersPage(groupId: 'g1', onClose: () {}),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls the page until [finder] is built and clear of the send bar.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
  }

  Future<void> tapSend(WidgetTester tester) async {
    await tester.tap(_sendButton);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('loads the recap of the current period with the headline and the rows', (tester) async {
    // Act
    await pumpReminders(tester);

    // Assert
    expect(reminders.periodIds, ['p4']);
    expect(find.textContaining('belum bayar periode 4', findRichText: true), findsOneWidget);
    expect(find.byType(RecapCard), findsOneWidget);
    await reveal(tester, find.widgetWithText(CheckRow, 'Pak Joko'));
    expect(find.text('Ingatkan satu per satu'), findsOneWidget);
    expect(find.widgetWithText(CheckRow, 'Pak Dedi'), findsOneWidget);
    expect(find.text('Tamu · lewat WhatsApp saja'), findsOneWidget);
  });

  testWidgets('share exports the recap at 1080 × 1350 and opens the share sheet', (tester) async {
    // Arrange
    await pumpReminders(tester);

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Bagikan rekap ke grup WhatsApp'));
    await tester.pumpAndSettle();

    // Assert
    final export = exporter.exports.single;
    expect(export.logicalSize * export.pixelRatio, const Size(1080, 1350));
    expect(share.sharedImages.single.png, exporter.bytes);
    expect(share.sharedImages.single.text, 'Rekap Arisan RT 05 periode 4');
  });

  testWidgets('WhatsApp opens wa.me with the amount, due date and account', (tester) async {
    // Arrange
    await pumpReminders(tester);
    await reveal(tester, _whatsAppFor('Pak Dedi'));

    // Act
    await tester.tap(_whatsAppFor('Pak Dedi'));
    await tester.pumpAndSettle();

    // Assert
    final sent = share.whatsApp.single;
    expect(sent.phone, '+6281234567890');
    expect(sent.text, contains('Halo Pak Dedi'));
    expect(sent.text, contains('Rp200.000'));
    expect(sent.text, contains('Sab, 24 Okt'));
    expect(sent.text, contains('BCA 1234567890 a.n. Rina'));
    final uri = ShareService.whatsAppUri(phone: sent.phone, text: sent.text);
    expect(uri.host, 'wa.me');
    expect(uri.path, '/6281234567890');
  });

  testWidgets('a member without a known number has no WhatsApp button', (tester) async {
    // Act
    await pumpReminders(tester);
    await reveal(tester, find.widgetWithText(CheckRow, 'Pak Joko'));

    // Assert
    expect(_whatsAppFor('Pak Joko'), findsNothing);
    expect(_whatsAppFor('Bu Ani'), findsOneWidget);
  });

  testWidgets('sends the selected members (not guests) with one key and confirms', (tester) async {
    // Arrange
    reminders.sendResult = const Right(ReminderResult(sentCount: 2));
    await pumpReminders(tester);

    // Act
    await tapSend(tester);
    await tester.pumpAndSettle();

    // Assert
    expect(reminders.memberIds.single, unorderedEquals(['m4', 'm9']));
    expect(reminders.keys, hasLength(1));
    expect(find.text('Notifikasi terkirim ke 2 orang'), findsOneWidget);
  });

  testWidgets('unticking a member sends only the rest', (tester) async {
    // Arrange
    await pumpReminders(tester);
    expect(find.widgetWithText(AppButton, 'Kirim notifikasi ke 2 orang'), findsOneWidget);

    await reveal(tester, find.widgetWithText(CheckRow, 'Pak Joko'));

    // Act
    await tester.tap(find.widgetWithText(CheckRow, 'Pak Joko'));
    await tester.pumpAndSettle();
    await tapSend(tester);
    await tester.pumpAndSettle();

    // Assert
    expect(reminders.memberIds.single, ['m4']);
  });

  testWidgets('a retry after a timeout reuses the idempotency key', (tester) async {
    // Arrange
    reminders.sendResults.add(const Left(Failure.timeout()));
    reminders.sendResult = const Right(ReminderResult(sentCount: 2));
    await pumpReminders(tester);

    // Act
    await tapSend(tester);
    await tester.pumpAndSettle();
    await tapSend(tester);
    await tester.pumpAndSettle();

    // Assert
    expect(reminders.keys, hasLength(2));
    expect(reminders.keys.toSet(), hasLength(1));
  });

  testWidgets('skipped members are listed by reason with WhatsApp buttons', (tester) async {
    // Arrange
    reminders.sendResult = const Right(
      ReminderResult(
        sentCount: 1,
        skipped: [
          SkippedReminder(member: _joko, reason: ReminderSkipReason.recentlyReminded, whatsappPhone: '+6281999'),
          SkippedReminder(member: _dedi, reason: ReminderSkipReason.notificationsOff),
        ],
      ),
    );
    await pumpReminders(tester);

    // Act
    await tapSend(tester);
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('2 orang tidak dapat notifikasi'), findsOneWidget);
    expect(find.text('Baru diingatkan'), findsOneWidget);
    expect(find.text('Notifikasi mati'), findsOneWidget);

    // Act
    await tester.tap(_whatsAppFor('Pak Joko').last);
    await tester.pumpAndSettle();

    // Assert
    expect(share.whatsApp.single.phone, '+6281999');
    expect(share.whatsApp.single.text, contains('Halo Pak Joko'));
  });

  testWidgets('rate_limit_exceeded shows a countdown and holds the button', (tester) async {
    // Arrange
    reminders.sendResult = const Left(Failure.tooManyRequests(retryAfter: Duration(seconds: 90)));
    await pumpReminders(tester);

    // Act
    await tapSend(tester);

    // Assert
    expect(find.byType(CountdownText), findsOneWidget);
    expect(find.textContaining('Bisa kirim lagi dalam'), findsOneWidget);
    expect(tester.widget<AppButton>(_sendButton).onPressed, isNull);
  });

  testWidgets('offline, sending is disabled with a reason', (tester) async {
    // Act
    await pumpReminders(tester, online: false);

    // Assert
    final button = tester.widget<AppButton>(_sendButton);
    expect(button.onPressed, isNull);
    expect(button.disabledReason, 'Butuh koneksi internet.');
  });

  testWidgets('everyone paid shows the empty state and keeps the share button', (tester) async {
    // Arrange
    reminders.recapResult = Right(_recap.copyWith(unpaid: const [], paidCount: 10));

    // Act
    await pumpReminders(tester);

    // Assert
    expect(find.text('Semua sudah bayar'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Bagikan rekap ke grup WhatsApp'), findsOneWidget);
    expect(_sendButton, findsNothing);
  });

  testWidgets('a group without a running period says so', (tester) async {
    // Arrange
    groups.groupResult = const Right(GroupDetail(id: 'g1'));

    // Act
    await pumpReminders(tester);

    // Assert
    expect(find.text('Belum ada periode berjalan'), findsOneWidget);
    expect(reminders.calls, isEmpty);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    // Arrange
    reminders.recapResult = const Left(Failure.network());
    await pumpReminders(tester);
    reminders.recapResult = Right(_recap);

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Coba lagi'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(RecapCard), findsOneWidget);
  });
}

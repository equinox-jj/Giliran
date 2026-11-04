import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/connectivity_controller.dart';
import 'package:giliran/core/services/image_picker_service.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/payment_method.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:giliran/features/payment/domain/entities/payment.dart';
import 'package:giliran/features/payment/domain/usecases/upload_proof_usecase.dart';
import 'package:giliran/features/payment/presentation/shared/widgets/mark_paid_sheet.dart';
import 'package:giliran/features/payment/presentation/shared/widgets/upload_proof_sheet.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fake_connectivity.dart';
import '../../../../helpers/fake_image_picker_service.dart';
import '../../../../helpers/fake_payment_repository.dart';
import '../../../../helpers/pump_app.dart';

const _group = GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  amount: 200000,
  paymentInfo: PaymentInfo(bankName: 'BCA', accountNumber: '1234567890', accountHolder: 'Sari'),
);

const _payment = Payment(
  id: 'pay1',
  periodId: 'p1',
  member: MemberRef(id: 'm1', displayName: 'Bu Sri', slotNo: 3),
  amount: 200000,
  status: PaymentStatus.unpaid,
);

/// A page with one button that opens the sheet under test and records its
/// result.
class const _Launcher({
  required final Future<Object?> Function(BuildContext) open,
  required final List<Object?> results,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(onPressed: () async => results.add(await open(context)), child: const Text('open')),
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakePaymentRepository payments;
  late FakeImagePickerService picker;
  late List<Object?> results;
  late String imagePath;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('proof_sheet');
    imagePath = (File('${dir.path}/proof.png')..writeAsBytesSync(_png)).path;
  });

  setUp(() {
    payments = FakePaymentRepository();
    picker = FakeImagePickerService()..next = (path: imagePath, denied: false);
    results = [];
  });

  Future<void> open(WidgetTester tester, Future<Object?> Function(BuildContext) sheet, {bool online = true}) async {
    final container = ProviderContainer(
      overrides: [
        paymentRepositoryProvider.overrideWithValue(payments),
        // Real file IO never completes inside the widget test's fake clock.
        uploadProofUseCaseProvider.overrideWithValue(UploadProofUseCase(payments, (_) async => 1024)),
        imagePickerServiceProvider.overrideWithValue(picker),
        connectivityControllerProvider.overrideWith(() => FakeConnectivityController(online)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      _Launcher(open: sheet, results: results),
      container: container,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<Object?> upload(BuildContext context, {Payment payment = _payment}) =>
      showUploadProofSheet(context, group: _group, payment: payment, periodNo: 4);

  Future<void> pickImage(WidgetTester tester) async {
    await tester.tap(find.text('Pilih bukti transfer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
  }

  AppButton submitButton(WidgetTester tester, String label) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, label));

  group('UploadProofSheet', () {
    testWidgets('a rejected payment shows the reason banner', (tester) async {
      // Act
      await open(
        tester,
        (c) => upload(
          c,
          payment: _payment.copyWith(status: PaymentStatus.rejected, rejectReason: 'Nominal kurang'),
        ),
      );

      // Assert
      expect(find.text('Bayar iuran periode 4'), findsOneWidget);
      expect(find.text('Bukti sebelumnya ditolak: Nominal kurang'), findsOneWidget);
    });

    testWidgets('Kirim bukti waits for an image and the transfer check', (tester) async {
      // Arrange
      await open(tester, upload);
      final before = submitButton(tester, 'Kirim bukti');

      // Act
      await pickImage(tester);
      final afterPick = submitButton(tester, 'Kirim bukti');
      await tester.ensureVisible(find.text('Saya sudah transfer Rp200.000'));
      await tester.tap(find.text('Saya sudah transfer Rp200.000'));
      await tester.pumpAndSettle();

      // Assert
      expect(before.onPressed, isNull);
      expect(before.disabledReason, 'Pilih bukti transfer dulu.');
      expect(afterPick.onPressed, isNull);
      expect(afterPick.disabledReason, 'Centang konfirmasi transfer dulu.');
      expect(submitButton(tester, 'Kirim bukti').onPressed, isNotNull);
    });

    testWidgets('file_too_large shows Ukuran maksimal 5 MB on the tile', (tester) async {
      // Arrange
      payments.writeResults.add(const Left(Failure.badRequest(code: ApiErrorCode.fileTooLarge, status: 413)));
      await open(tester, upload);
      await pickImage(tester);
      await tester.ensureVisible(find.text('Saya sudah transfer Rp200.000'));
      await tester.tap(find.text('Saya sudah transfer Rp200.000'));
      await tester.pumpAndSettle();

      // Act
      await tester.ensureVisible(find.text('Kirim bukti'));
      await tester.tap(find.text('Kirim bukti'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Ukuran maksimal 5 MB'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('a retry after a failure reuses the idempotency key', (tester) async {
      // Arrange
      payments.writeResults.add(const Left(Failure.timeout()));
      await open(tester, upload);
      await pickImage(tester);
      await tester.ensureVisible(find.text('Saya sudah transfer Rp200.000'));
      await tester.tap(find.text('Saya sudah transfer Rp200.000'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kirim bukti'));
      await tester.tap(find.text('Kirim bukti'));
      await tester.pumpAndSettle();

      // Act
      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      // Assert
      expect(payments.keys, hasLength(2));
      expect(payments.keys.toSet(), hasLength(1));
    });

    testWidgets('success closes the sheet with a medium haptic', (tester) async {
      // Arrange
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await open(tester, upload);
      await pickImage(tester);
      await tester.ensureVisible(find.text('Saya sudah transfer Rp200.000'));
      await tester.tap(find.text('Saya sudah transfer Rp200.000'));
      await tester.pumpAndSettle();

      // Act
      await tester.ensureVisible(find.text('Kirim bukti'));
      await tester.tap(find.text('Kirim bukti'));
      await tester.pumpAndSettle();

      // Assert
      expect(results, [true]);
      expect(find.text('Bayar iuran periode 4'), findsNothing);
      expect(haptics, contains('HapticFeedbackType.mediumImpact'));
      expect(payments.lastPath, imagePath);
    });

    testWidgets('offline, Kirim bukti says it needs a connection', (tester) async {
      // Arrange
      await open(tester, upload, online: false);

      // Act
      await pickImage(tester);

      // Assert
      expect(submitButton(tester, 'Kirim bukti').disabledReason, 'Butuh koneksi internet.');
    });
  });

  group('MarkPaidSheet', () {
    Future<Object?> markPaid(BuildContext context) => showMarkPaidSheet(context, groupId: 'g1', payment: _payment);

    testWidgets('Catat sudah bayar waits for the money-received check', (tester) async {
      // Arrange
      await open(tester, markPaid);
      final before = submitButton(tester, 'Catat sudah bayar');

      // Act
      await tester.tap(find.text('Uang sudah saya terima'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Catat pembayaran Bu Sri'), findsOneWidget);
      expect(before.onPressed, isNull);
      expect(submitButton(tester, 'Catat sudah bayar').onPressed, isNotNull);
    });

    for (final (label, method) in [
      ('Tunai', PaymentMethod.cash),
      ('Transfer', PaymentMethod.transfer),
      ('Lainnya', PaymentMethod.other),
    ]) {
      testWidgets('$label sends ${method.apiValue}', (tester) async {
        // Arrange
        await open(tester, markPaid);
        await tester.tap(find.widgetWithText(AppChip, label));
        await tester.tap(find.text('Uang sudah saya terima'));
        await tester.pumpAndSettle();

        // Act
        await tester.ensureVisible(find.text('Catat sudah bayar'));
        await tester.tap(find.text('Catat sudah bayar'));
        await tester.pumpAndSettle();

        // Assert
        expect(payments.lastMethod, method);
        expect(results.single, isA<Payment>());
      });
    }

    testWidgets('a note over 500 characters blocks the button', (tester) async {
      // Arrange
      await open(tester, markPaid);
      await tester.tap(find.text('Uang sudah saya terima'));

      // Act
      await tester.enterText(find.byType(TextField), 'x' * 501);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Catatan maksimal 500 karakter.'), findsOneWidget);
      expect(submitButton(tester, 'Catat sudah bayar').onPressed, isNull);
    });

    testWidgets('the note is sent with the mark', (tester) async {
      // Arrange
      await open(tester, markPaid);
      await tester.enterText(find.byType(TextField), 'Dibayar di rumah Bu Ani');
      await tester.tap(find.text('Uang sudah saya terima'));
      await tester.pumpAndSettle();

      // Act
      await tester.ensureVisible(find.text('Catat sudah bayar'));
      await tester.tap(find.text('Catat sudah bayar'));
      await tester.pumpAndSettle();

      // Assert
      expect(payments.lastNote, 'Dibayar di rumah Bu Ani');
    });
  });
}

const _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/network/connectivity_controller.dart';
import 'package:giliran/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:giliran/features/payment/domain/entities/payment.dart';
import 'package:giliran/features/payment/presentation/shared/controllers/payment_sync_controller.dart';
import 'package:giliran/features/payment/presentation/shared/widgets/payment_sync_listener.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fake_payment_repository.dart';
import '../../../../helpers/pump_app.dart';

/// Connectivity driven by the test through [controller].
class _ManualConnectivity(final StreamController<bool> controller) extends ConnectivityController {
  @override
  Stream<bool> build() => controller.stream;
}

void main() {
  late FakePaymentRepository payments;
  late StreamController<bool> online;

  setUp(() {
    payments = FakePaymentRepository();
    online = StreamController<bool>.broadcast();
  });
  tearDown(() => online.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        paymentRepositoryProvider.overrideWithValue(payments),
        connectivityControllerProvider.overrideWith(() => _ManualConnectivity(online)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('syncs when the device comes back online', () async {
    // Arrange
    final c = container();
    c.listen(paymentSyncControllerProvider, (_, _) {});
    online.add(false);
    await Future<void>.delayed(Duration.zero);

    // Act
    online.add(true);
    await Future<void>.delayed(Duration.zero);

    // Assert
    expect(payments.calls, ['syncPendingPayments']);
  });

  test('does not sync again while staying online', () async {
    // Arrange
    final c = container();
    c.listen(paymentSyncControllerProvider, (_, _) {});
    online.add(true);
    await Future<void>.delayed(Duration.zero);

    // Act
    online.add(true);
    await Future<void>.delayed(Duration.zero);

    // Assert
    expect(payments.calls, ['syncPendingPayments']);
  });

  testWidgets('a refused mark shows the not-saved toast', (tester) async {
    // Arrange
    payments.syncResult = const Right(SyncReport(rejected: [Payment(id: 'pay1')]));
    final c = container();
    await tester.pumpPage(
      const PaymentSyncListener(child: Scaffold(body: SizedBox())),
      container: c,
    );

    // Act
    online.add(true);
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Perubahan tidak tersimpan: pembayaran sudah dicatat pengurus lain.'), findsOneWidget);
  });
}

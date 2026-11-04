import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/network/connectivity_controller.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/sync_pending_payments_usecase.dart';

part 'payment_sync_controller.g.dart';

/// Sends offline cash marks when the device comes back online (and once on
/// start). Its state is the last sync's report; the app shell listens to
/// it to tell the user about marks the server refused.
@Riverpod(keepAlive: true)
class PaymentSyncController() extends _$PaymentSyncController {
  var _running = false;

  @override
  SyncReport? build() {
    ref.listen(connectivityControllerProvider, (previous, next) {
      final online = next.value ?? false;
      final wasOnline = previous?.value ?? false;
      if (online && !wasOnline) unawaited(sync());
    }, fireImmediately: true);
    return null;
  }

  /// Runs one sync unless one is already running. Returns its report.
  Future<SyncReport?> sync() async {
    if (_running) return null;
    _running = true;
    try {
      final result = await ref.read(syncPendingPaymentsUseCaseProvider)(const NoParams());
      final report = result.toNullable();
      if (ref.mounted && report != null) state = report;
      return report;
    } finally {
      _running = false;
    }
  }
}

import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

part 'sync_pending_payments_usecase.g.dart';

/// Sends every offline cash mark with its stored key. Marks the server
/// refuses are dropped, their rows go back to server state, and they are
/// listed in [SyncReport.rejected] so the user can be told.
class const SyncPendingPaymentsUseCase(final PaymentRepository _repository) implements UseCase<SyncReport, NoParams> {
  @override
  Future<Either<Failure, SyncReport>> call(NoParams params) => _repository.syncPendingPayments();
}

@Riverpod(keepAlive: true)
SyncPendingPaymentsUseCase syncPendingPaymentsUseCase(Ref ref) =>
    SyncPendingPaymentsUseCase(ref.watch(paymentRepositoryProvider));

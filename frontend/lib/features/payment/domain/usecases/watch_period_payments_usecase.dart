import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

part 'watch_period_payments_usecase.g.dart';

/// A period's cached payment board by slot number, live.
class const WatchPeriodPaymentsUseCase(final PaymentRepository _repository)
    implements StreamUseCase<List<Payment>, String> {
  @override
  Stream<Either<Failure, List<Payment>>> call(String params) => _repository.watchPeriodPayments(params);
}

@Riverpod(keepAlive: true)
WatchPeriodPaymentsUseCase watchPeriodPaymentsUseCase(Ref ref) =>
    WatchPeriodPaymentsUseCase(ref.watch(paymentRepositoryProvider));

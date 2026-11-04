import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../repositories/payment_repository.dart';

part 'refresh_period_payments_usecase.g.dart';

typedef PeriodRef = ({String groupId, String periodId});

/// Fetches a period's payment board and summary into the cache.
class const RefreshPeriodPaymentsUseCase(final PaymentRepository _repository) implements UseCase<Unit, PeriodRef> {
  @override
  Future<Either<Failure, Unit>> call(PeriodRef params) =>
      _repository.refreshPeriodPayments(params.groupId, params.periodId);
}

@Riverpod(keepAlive: true)
RefreshPeriodPaymentsUseCase refreshPeriodPaymentsUseCase(Ref ref) =>
    RefreshPeriodPaymentsUseCase(ref.watch(paymentRepositoryProvider));

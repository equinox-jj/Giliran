import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../repositories/payment_repository.dart';

part 'refresh_periods_usecase.g.dart';

/// Fetches a group's periods into the cache (server wins).
class const RefreshPeriodsUseCase(final PaymentRepository _repository) implements UseCase<Unit, String> {
  @override
  Future<Either<Failure, Unit>> call(String params) => _repository.refreshPeriods(params);
}

@Riverpod(keepAlive: true)
RefreshPeriodsUseCase refreshPeriodsUseCase(Ref ref) => RefreshPeriodsUseCase(ref.watch(paymentRepositoryProvider));

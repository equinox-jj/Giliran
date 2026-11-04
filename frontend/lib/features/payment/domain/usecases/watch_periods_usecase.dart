import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../entities/period.dart';
import '../repositories/payment_repository.dart';

part 'watch_periods_usecase.g.dart';

/// A group's cached periods by number, live.
class const WatchPeriodsUseCase(final PaymentRepository _repository) implements StreamUseCase<List<Period>, String> {
  @override
  Stream<Either<Failure, List<Period>>> call(String params) => _repository.watchPeriods(params);
}

@Riverpod(keepAlive: true)
WatchPeriodsUseCase watchPeriodsUseCase(Ref ref) => WatchPeriodsUseCase(ref.watch(paymentRepositoryProvider));

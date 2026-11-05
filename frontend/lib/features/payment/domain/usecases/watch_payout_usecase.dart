import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../entities/payout.dart';
import '../repositories/payment_repository.dart';

part 'watch_payout_usecase.g.dart';

/// A period's cached payout, live; null until one is recorded.
class const WatchPayoutUseCase(final PaymentRepository _repository) implements StreamUseCase<Payout?, String> {
  @override
  Stream<Either<Failure, Payout?>> call(String params) => _repository.watchPayout(params);
}

@Riverpod(keepAlive: true)
WatchPayoutUseCase watchPayoutUseCase(Ref ref) => WatchPayoutUseCase(ref.watch(paymentRepositoryProvider));

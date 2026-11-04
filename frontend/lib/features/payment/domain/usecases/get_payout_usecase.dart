import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../entities/payout.dart';
import '../repositories/payment_repository.dart';

part 'get_payout_usecase.g.dart';

typedef PayoutRef = ({String groupId, String periodId});

/// A period's payout record, fetched into the cache (S40).
class const GetPayoutUseCase(final PaymentRepository _repository) implements UseCase<Payout, PayoutRef> {
  @override
  Future<Either<Failure, Payout>> call(PayoutRef params) => _repository.getPayout(params.groupId, params.periodId);
}

@Riverpod(keepAlive: true)
GetPayoutUseCase getPayoutUseCase(Ref ref) => GetPayoutUseCase(ref.watch(paymentRepositoryProvider));

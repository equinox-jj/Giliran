import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/idempotency.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../entities/payout.dart';
import '../repositories/payment_repository.dart';

part 'confirm_payout_usecase.g.dart';

typedef ConfirmPayoutParams = ({String groupId, String periodId, IdempotencyKey key});

/// The winner confirms the pot arrived (S40).
class const ConfirmPayoutUseCase(final PaymentRepository _repository) implements UseCase<Payout, ConfirmPayoutParams> {
  @override
  Future<Either<Failure, Payout>> call(ConfirmPayoutParams params) =>
      _repository.confirmPayout(params.groupId, params.periodId, key: params.key);
}

@Riverpod(keepAlive: true)
ConfirmPayoutUseCase confirmPayoutUseCase(Ref ref) => ConfirmPayoutUseCase(ref.watch(paymentRepositoryProvider));

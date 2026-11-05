import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/idempotency.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../entities/payout.dart';
import '../repositories/payment_repository.dart';

part 'record_payout_usecase.g.dart';

typedef RecordPayoutParams = ({
  String groupId,
  String periodId,
  String? proofPath,
  String? note,
  IdempotencyKey key,
});

/// Records that the pot went to the winner; the period closes and
/// the next one opens.
class const RecordPayoutUseCase(final PaymentRepository _repository) implements UseCase<Payout, RecordPayoutParams> {
  @override
  Future<Either<Failure, Payout>> call(RecordPayoutParams params) => _repository.recordPayout(
    params.groupId,
    params.periodId,
    proofPath: params.proofPath,
    note: params.note,
    key: params.key,
  );
}

@Riverpod(keepAlive: true)
RecordPayoutUseCase recordPayoutUseCase(Ref ref) => RecordPayoutUseCase(ref.watch(paymentRepositoryProvider));

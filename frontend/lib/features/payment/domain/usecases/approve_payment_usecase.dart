import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/idempotency.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

part 'approve_payment_usecase.g.dart';

typedef ApprovePaymentParams = ({String groupId, String paymentId, IdempotencyKey key});

/// Approves a pending proof (S35): `pending_review` → `paid`. Reuse [key]
/// when retrying the same approval.
class const ApprovePaymentUseCase(final PaymentRepository _repository)
    implements UseCase<Payment, ApprovePaymentParams> {
  @override
  Future<Either<Failure, Payment>> call(ApprovePaymentParams params) =>
      _repository.approvePayment(params.groupId, params.paymentId, key: params.key);
}

@Riverpod(keepAlive: true)
ApprovePaymentUseCase approvePaymentUseCase(Ref ref) => ApprovePaymentUseCase(ref.watch(paymentRepositoryProvider));

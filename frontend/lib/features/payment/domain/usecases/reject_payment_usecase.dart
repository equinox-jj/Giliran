import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/problem_details.dart';
import '../../../../core/network/idempotency.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

part 'reject_payment_usecase.g.dart';

typedef RejectPaymentParams = ({String groupId, String paymentId, String reason, IdempotencyKey key});

/// Rejects a pending proof with a reason the payer sees (S35). The trimmed
/// reason must be [minLength]–[maxLength] characters, else it fails with a
/// [ValidationFailure] on `reason` before any request.
class const RejectPaymentUseCase(final PaymentRepository _repository) implements UseCase<Payment, RejectPaymentParams> {
  static const minLength = 3;
  static const maxLength = 500;

  @override
  Future<Either<Failure, Payment>> call(RejectPaymentParams params) async {
    final reason = params.reason.trim();
    if (reason.length < minLength || reason.length > maxLength) {
      return const Left(
        Failure.validation(
          fieldErrors: [FieldError(field: 'reason', code: 'invalid_length', message: '')],
        ),
      );
    }
    return _repository.rejectPayment(params.groupId, params.paymentId, reason: reason, key: params.key);
  }
}

@Riverpod(keepAlive: true)
RejectPaymentUseCase rejectPaymentUseCase(Ref ref) => RejectPaymentUseCase(ref.watch(paymentRepositoryProvider));

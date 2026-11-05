import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/problem_details.dart';
import '../../../../core/network/idempotency.dart';
import '../../../../core/utils/enums/payment_method.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

part 'mark_paid_usecase.g.dart';

typedef MarkPaidParams = ({
  String groupId,
  String paymentId,
  PaymentMethod method,
  String? note,
  IdempotencyKey key,
});

/// Records a payment as paid without a proof: cash, guests. Works
/// offline: the mark is queued with `pendingSync` and synced later. A note
/// over [maxNoteLength] fails with a [ValidationFailure] on `note`; a blank
/// note is sent as none.
class const MarkPaidUseCase(final PaymentRepository _repository) implements UseCase<Payment, MarkPaidParams> {
  static const maxNoteLength = 500;

  @override
  Future<Either<Failure, Payment>> call(MarkPaidParams params) async {
    final note = params.note?.trim();
    if (note != null && note.length > maxNoteLength) {
      return const Left(
        Failure.validation(
          fieldErrors: [FieldError(field: 'note', code: 'too_long', message: '')],
        ),
      );
    }
    return _repository.markPaid(
      params.groupId,
      params.paymentId,
      method: params.method,
      note: note == null || note.isEmpty ? null : note,
      key: params.key,
    );
  }
}

@Riverpod(keepAlive: true)
MarkPaidUseCase markPaidUseCase(Ref ref) => MarkPaidUseCase(ref.watch(paymentRepositoryProvider));

import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

part 'get_payment_detail_usecase.g.dart';

typedef PaymentRef = ({String groupId, String paymentId});

/// One payment with every proof, fresh from the API (S35, proof viewer).
class const GetPaymentDetailUseCase(final PaymentRepository _repository) implements UseCase<Payment, PaymentRef> {
  @override
  Future<Either<Failure, Payment>> call(PaymentRef params) =>
      _repository.getPaymentDetail(params.groupId, params.paymentId);
}

@Riverpod(keepAlive: true)
GetPaymentDetailUseCase getPaymentDetailUseCase(Ref ref) =>
    GetPaymentDetailUseCase(ref.watch(paymentRepositoryProvider));

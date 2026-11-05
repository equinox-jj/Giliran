import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/idempotency.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/enums/api_error_code.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

part 'upload_proof_usecase.g.dart';

typedef UploadProofParams = ({
  String groupId,
  String paymentId,
  String path,
  IdempotencyKey key,
  void Function(double progress)? onProgress,
});

/// Sends a transfer screenshot as the payment's proof. The picker
/// already resized and re-encoded it (§8.21); a file still over [maxBytes]
/// fails with `file_too_large` before any upload, like the server would.
class const UploadProofUseCase(
  final PaymentRepository _repository,
  final Future<int> Function(String path) _fileSize,
) implements UseCase<Payment, UploadProofParams> {
  static const maxBytes = 5 * 1024 * 1024;

  @override
  Future<Either<Failure, Payment>> call(UploadProofParams params) async {
    if (await _fileSize(params.path) > maxBytes) {
      return const Left(Failure.badRequest(code: ApiErrorCode.fileTooLarge, status: 413));
    }
    return _repository.uploadProof(
      params.groupId,
      params.paymentId,
      params.path,
      key: params.key,
      onProgress: params.onProgress,
    );
  }
}

@Riverpod(keepAlive: true)
UploadProofUseCase uploadProofUseCase(Ref ref) =>
    UploadProofUseCase(ref.watch(paymentRepositoryProvider), (path) => File(path).length());

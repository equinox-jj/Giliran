import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/group.dart';
import '../../../domain/entities/group_input.dart';
import '../../../domain/usecases/delete_qris_usecase.dart';
import '../../../domain/usecases/pick_qris_image_usecase.dart';
import '../../../domain/usecases/refresh_group_usecase.dart';
import '../../../domain/usecases/update_payment_info_usecase.dart';
import '../../../domain/usecases/upload_qris_usecase.dart';
import '../../../domain/usecases/watch_group_usecase.dart';

part 'payment_info_controller.freezed.dart';
part 'payment_info_controller.g.dart';

/// Payment info: the group as last fetched (with the signed QRIS URL
/// when online) and the state of the save and QRIS actions.
@freezed
abstract class PaymentInfoState with _$PaymentInfoState {
  const factory({
    required GroupDetail group,
    @Default(false) bool saving,
    @Default(false) bool uploadingQris,

    /// The last failed save; field errors show under their fields.
    Failure? saveFailure,

    /// The server rejected the QRIS image (field `file`); the message to
    /// show, or empty for the default copy.
    String? qrisError,
  }) = _PaymentInfoState;
}

/// How a QRIS upload attempt ended.
enum QrisUploadOutcome() {
  uploaded,
  cancelled,
  denied,
  rejected,
  failed,
}

/// Loads the group fresh from the API (the only place the signed QRIS URL
/// appears, falling back to the cache offline), saves the bank account and
/// uploads or removes the QRIS.
@riverpod
class PaymentInfoController() extends _$PaymentInfoController {
  @override
  Future<PaymentInfoState> build(String groupId) async {
    final fresh = await ref.read(refreshGroupUseCaseProvider)(groupId);
    if (fresh case Right(:final value)) return PaymentInfoState(group: value);
    final cached = await ref.read(watchGroupUseCaseProvider)(groupId).first;
    final group = cached.toNullable();
    if (group == null) throw fresh.getLeft().toNullable() ?? const Failure.unknown();
    return PaymentInfoState(group: group);
  }

  /// Saves the bank account. Returns the failure, if any.
  Future<Failure?> save(PaymentInfoInput input) async {
    final current = state.value;
    if (current == null || current.saving) return null;
    state = AsyncData(current.copyWith(saving: true, saveFailure: null));
    final result = await ref.read(updatePaymentInfoUseCaseProvider)((groupId: groupId, input: input));
    if (!ref.mounted) return result.getLeft().toNullable();
    state = AsyncData(
      switch (result) {
        Left(:final value) => current.copyWith(saving: false, saveFailure: value),
        Right(:final value) => current.copyWith(saving: false, group: value),
      },
    );
    return result.getLeft().toNullable();
  }

  /// Picks an image from the gallery and uploads it as the QRIS.
  Future<QrisUploadOutcome> uploadQris() async {
    final current = state.value;
    if (current == null || current.uploadingQris) return QrisUploadOutcome.cancelled;
    final picked = (await ref.read(pickQrisImageUseCaseProvider)(const NoParams())).toNullable();
    if (picked == null || !ref.mounted) return QrisUploadOutcome.cancelled;
    if (picked.denied) return QrisUploadOutcome.denied;
    final path = picked.path;
    if (path == null) return QrisUploadOutcome.cancelled;

    state = AsyncData(current.copyWith(uploadingQris: true, qrisError: null));
    final result = await ref.read(uploadQrisUseCaseProvider)((groupId: groupId, path: path));
    if (!ref.mounted) return result.isRight() ? QrisUploadOutcome.uploaded : QrisUploadOutcome.failed;
    switch (result) {
      case Right(:final value):
        state = AsyncData(current.copyWith(uploadingQris: false, group: value));
        return QrisUploadOutcome.uploaded;
      case Left(value: ValidationFailure(:final fieldErrors)):
        final message = fieldErrors.where((e) => e.field == 'file').firstOrNull?.message ?? '';
        state = AsyncData(current.copyWith(uploadingQris: false, qrisError: message));
        return QrisUploadOutcome.rejected;
      case Left():
        state = AsyncData(current.copyWith(uploadingQris: false));
        return QrisUploadOutcome.failed;
    }
  }

  /// Removes the QRIS. Returns the failure, if any.
  Future<Failure?> removeQris() async {
    final current = state.value;
    if (current == null) return null;
    final result = await ref.read(deleteQrisUseCaseProvider)(groupId);
    if (!ref.mounted || result.isLeft()) return result.getLeft().toNullable();
    final info = current.group.paymentInfo ?? const PaymentInfo();
    state = AsyncData(
      current.copyWith(
        qrisError: null,
        group: current.group.copyWith(
          paymentInfo: info.copyWith(hasQris: false, qrisImageUrl: null, qrisMerchantName: null),
        ),
      ),
    );
    return null;
  }
}

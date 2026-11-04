import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/network/idempotency.dart';
import '../../../../../core/services/image_picker_service.dart';
import '../../../../../core/utils/enums/photo_source.dart';
import '../../../domain/usecases/upload_proof_usecase.dart';

part 'upload_proof_controller.freezed.dart';
part 'upload_proof_controller.g.dart';

/// The Upload proof sheet (S34): the picked image, the "I transferred"
/// check, upload progress, and the last failure.
@freezed
abstract class const UploadProofState._() with _$UploadProofState {
  const factory({
    String? path,
    @Default(false) bool confirmed,

    /// Sent fraction while uploading, else null.
    double? progress,
    Failure? failure,

    /// The user blocked camera or photo access.
    @Default(false) bool denied,
    @Default(false) bool done,
  }) = _UploadProofState;

  bool get uploading => progress != null;

  bool get canSubmit => path != null && confirmed && !uploading && !done;
}

/// Picks and uploads a payment proof. One [IdempotencyKey] covers one
/// image: a retry after a failure reuses it, a new image gets a new one.
@riverpod
class UploadProofController() extends _$UploadProofController {
  IdempotencyKey? _key;

  @override
  UploadProofState build(String groupId, String paymentId) => const UploadProofState();

  Future<void> pick(PhotoSource source) async {
    final picked = await ref.read(imagePickerServiceProvider).pick(source);
    if (!ref.mounted) return;
    if (picked.path == null) {
      state = state.copyWith(denied: picked.denied);
      return;
    }
    _key = null;
    state = state.copyWith(path: picked.path, failure: null, denied: false);
  }

  void remove() {
    _key = null;
    state = state.copyWith(path: null, failure: null);
  }

  void setConfirmed(bool value) => state = state.copyWith(confirmed: value);

  /// Uploads the picked image. Returns true when the proof was sent.
  Future<bool> submit() async {
    final path = state.path;
    if (path == null || !state.canSubmit) return false;
    final key = _key ??= IdempotencyKey.generate();
    state = state.copyWith(progress: 0, failure: null);
    final result = await ref.read(uploadProofUseCaseProvider)((
      groupId: groupId,
      paymentId: paymentId,
      path: path,
      key: key,
      onProgress: (p) {
        if (ref.mounted && state.uploading) state = state.copyWith(progress: p);
      },
    ));
    if (!ref.mounted) return result.isRight();
    return result.match(
      (failure) {
        state = state.copyWith(progress: null, failure: failure);
        return false;
      },
      (_) {
        _key = null;
        state = state.copyWith(progress: null, done: true);
        return true;
      },
    );
  }
}

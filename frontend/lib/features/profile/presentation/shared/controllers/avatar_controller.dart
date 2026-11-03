import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../../core/utils/enums/photo_source.dart';
import '../../../../auth/domain/entities/auth_status.dart';
import '../../../../auth/presentation/shared/controllers/auth_session_controller.dart';
import '../../../domain/usecases/delete_avatar_usecase.dart';
import '../../../domain/usecases/pick_avatar_photo_usecase.dart';
import '../../../domain/usecases/upload_avatar_usecase.dart';

part 'avatar_controller.g.dart';

class const AvatarState({
  /// The photo picked on this device, shown while it uploads and after.
  final String? localPath,

  /// The uploaded photo from the server.
  final String? imageUrl,

  /// Sent fraction (0–1) while uploading, null otherwise.
  final double? progress,

  /// Why the last upload or removal failed.
  final Failure? failure,
}) {
  bool get hasPhoto => localPath != null || imageUrl != null;
  bool get uploading => progress != null;

  /// Uploaded and confirmed by the server.
  bool get done => imageUrl != null && progress == null && failure == null;
}

/// Picks, uploads and removes the profile picture. The photo is optional, so
/// a failed upload never blocks the rest of the screen. Starts from the
/// signed-in user's current photo, so Edit profile can remove it.
@riverpod
class AvatarController() extends _$AvatarController {
  @override
  AvatarState build() {
    final user = switch (ref.read(authSessionControllerProvider).value) {
      AuthUnlocked(:final user) || AuthLocked(:final user) => user,
      _ => null,
    };
    return AvatarState(imageUrl: user?.avatarUrl);
  }

  /// Takes or chooses a photo from [source] and uploads it. Returns false
  /// when the user blocked camera or photo access.
  Future<bool> pick(PhotoSource source) async {
    if (state.uploading) return true;
    final picked = await ref.read(pickAvatarPhotoUseCaseProvider)(source);
    final photo = picked.toNullable();
    if (!ref.mounted || photo == null) return true;
    if (photo.denied) return false;
    if (photo.path case final path?) await _upload(path);
    return true;
  }

  /// Sends the last picked photo again after a failed upload.
  Future<void> retry() async {
    if (state.localPath case final path? when !state.uploading) {
      await _upload(path);
    }
  }

  /// Removes the photo. Returns the failure when the server kept it.
  Future<Failure?> remove() async {
    if (state.uploading) return null;
    if (state.imageUrl == null) {
      // Never reached the server: nothing to delete.
      state = const AvatarState();
      return null;
    }
    final result = await ref.read(deleteAvatarUseCaseProvider)(const NoParams());
    if (!ref.mounted) return null;
    switch (result) {
      case Left(:final value):
        return value;
      case Right():
        state = const AvatarState();
        return null;
    }
  }

  Future<void> _upload(String path) async {
    state = AvatarState(localPath: path, progress: 0);
    final result = await ref.read(uploadAvatarUseCaseProvider)((
      path: path,
      onProgress: (sent) {
        if (ref.mounted && state.uploading) {
          state = AvatarState(localPath: path, progress: sent);
        }
      },
    ));
    if (!ref.mounted) return;
    state = switch (result) {
      Left(:final value) => AvatarState(localPath: path, failure: value),
      Right(:final value) => AvatarState(localPath: path, imageUrl: value.avatarUrl),
    };
  }
}

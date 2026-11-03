import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/services/image_picker_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/enums/photo_source.dart';

part 'pick_avatar_photo_usecase.g.dart';

class const PickAvatarPhotoUseCase(final ImagePickerService _picker) implements UseCase<PickedPhoto, PhotoSource> {
  @override
  Future<Either<Failure, PickedPhoto>> call(PhotoSource params) async => Right(await _picker.pick(params));
}

@Riverpod(keepAlive: true)
PickAvatarPhotoUseCase pickAvatarPhotoUseCase(Ref ref) => PickAvatarPhotoUseCase(ref.watch(imagePickerServiceProvider));

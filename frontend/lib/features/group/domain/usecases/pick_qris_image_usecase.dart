import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/services/image_picker_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/enums/photo_source.dart';

part 'pick_qris_image_usecase.g.dart';

/// Picks the QRIS image from the gallery (it is usually a screenshot from
/// the bank app), compressed on the device like every upload.
class const PickQrisImageUseCase(final ImagePickerService _picker) implements UseCase<PickedPhoto, NoParams> {
  @override
  Future<Either<Failure, PickedPhoto>> call(NoParams params) async => Right(await _picker.pick(PhotoSource.gallery));
}

@Riverpod(keepAlive: true)
PickQrisImageUseCase pickQrisImageUseCase(Ref ref) => PickQrisImageUseCase(ref.watch(imagePickerServiceProvider));

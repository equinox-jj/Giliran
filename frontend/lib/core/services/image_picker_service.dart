import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/enums/photo_source.dart';
import '../utils/logger/app_logger.dart';

part 'image_picker_service.g.dart';

/// What [ImagePickerService.pick] got: the file path, nothing (cancelled), or
/// [denied] when the user blocked camera or photo access.
typedef PickedPhoto = ({String? path, bool denied});

/// Thin wrapper over `image_picker` for every upload tile (avatar, payment
/// proof, QRIS). Images are compressed on device before upload (§8.21).
class const ImagePickerService(final ImagePicker _picker) {
  static const _tag = 'image_picker';

  /// Long edge after resizing, and JPEG quality (§8.21).
  static const maxDimension = 1600.0;
  static const quality = 80;

  /// Opens the camera or the gallery. A cancel returns a null path.
  Future<PickedPhoto> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: maxDimension,
        maxHeight: maxDimension,
        imageQuality: quality,
        requestFullMetadata: false,
      );
      return (path: file?.path, denied: false);
    } on PlatformException catch (e) {
      AppLogger.w('pick failed: ${e.code}', tag: _tag);
      return (path: null, denied: e.code.endsWith('access_denied'));
    }
  }
}

@Riverpod(keepAlive: true)
ImagePickerService imagePickerService(Ref ref) => ImagePickerService(ImagePicker());

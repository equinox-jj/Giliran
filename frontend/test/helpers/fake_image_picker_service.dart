import 'package:giliran/core/services/image_picker_service.dart';
import 'package:giliran/core/utils/enums/photo_source.dart';

/// Answers every `pick` with [next] and records the sources asked for.
class FakeImagePickerService() implements ImagePickerService {
  PickedPhoto next = (path: '/tmp/photo.jpg', denied: false);
  final sources = <PhotoSource>[];

  @override
  Future<PickedPhoto> pick(PhotoSource source) async {
    sources.add(source);
    return next;
  }
}

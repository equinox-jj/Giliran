import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../repositories/settings_repository.dart';

part 'clear_image_cache_usecase.g.dart';

/// "Hapus cache gambar": images download again the next time they show.
class ClearImageCacheUseCase(final SettingsRepository _repository) implements UseCase<Unit, NoParams> {
  @override
  Future<Either<Failure, Unit>> call(NoParams params) => _repository.clearImageCache();
}

@Riverpod(keepAlive: true)
ClearImageCacheUseCase clearImageCacheUseCase(Ref ref) => ClearImageCacheUseCase(ref.watch(settingsRepositoryProvider));

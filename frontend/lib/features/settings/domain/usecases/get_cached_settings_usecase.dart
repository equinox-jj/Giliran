import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../entities/user_settings.dart';
import '../repositories/settings_repository.dart';

part 'get_cached_settings_usecase.g.dart';

/// The settings saved on this device, shown on Settings while the server
/// copy loads. Null when none are saved.
class GetCachedSettingsUseCase(final SettingsRepository _repository) implements UseCase<UserSettings?, NoParams> {
  @override
  Future<Either<Failure, UserSettings?>> call(NoParams params) => _repository.getCachedSettings();
}

@Riverpod(keepAlive: true)
GetCachedSettingsUseCase getCachedSettingsUseCase(Ref ref) =>
    GetCachedSettingsUseCase(ref.watch(settingsRepositoryProvider));

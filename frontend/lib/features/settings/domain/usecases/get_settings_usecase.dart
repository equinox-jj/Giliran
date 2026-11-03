import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../entities/user_settings.dart';
import '../repositories/settings_repository.dart';

part 'get_settings_usecase.g.dart';

class GetSettingsUseCase(final SettingsRepository _repository) implements UseCase<UserSettings, NoParams> {
  @override
  Future<Either<Failure, UserSettings>> call(NoParams params) => _repository.getSettings();
}

@Riverpod(keepAlive: true)
GetSettingsUseCase getSettingsUseCase(Ref ref) => GetSettingsUseCase(ref.watch(settingsRepositoryProvider));

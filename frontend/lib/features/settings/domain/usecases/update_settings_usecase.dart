import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../entities/user_settings.dart';
import '../repositories/settings_repository.dart';

part 'update_settings_usecase.g.dart';

/// Changes the settings set in the patch; the rest stay as they are. An
/// empty patch is not sent, since the API needs at least one field.
class UpdateSettingsUseCase(final SettingsRepository _repository) implements UseCase<UserSettings?, UserSettingsPatch> {
  @override
  Future<Either<Failure, UserSettings?>> call(UserSettingsPatch patch) async {
    if (patch == const UserSettingsPatch()) return const Right(null);
    return _repository.updateSettings(patch);
  }
}

@Riverpod(keepAlive: true)
UpdateSettingsUseCase updateSettingsUseCase(Ref ref) => UpdateSettingsUseCase(ref.watch(settingsRepositoryProvider));

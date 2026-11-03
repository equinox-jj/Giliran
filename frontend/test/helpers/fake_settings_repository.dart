import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/settings/domain/entities/user_settings.dart';
import 'package:giliran/features/settings/domain/repositories/settings_repository.dart';

/// Answers `getSettings` with [settingsResult]. `updateSettings` records each
/// patch and answers with [updateResult], or applies the patch to the
/// current settings. `clearImageCache` counts calls.
class FakeSettingsRepository() implements SettingsRepository {
  Either<Failure, UserSettings> settingsResult = const Right(
    UserSettings(
      language: 'id',
      notifyPaymentReminders: true,
      notifyDrawResults: true,
      notifyGroupActivity: false,
    ),
  );
  Either<Failure, UserSettings>? updateResult;
  Either<Failure, Unit> clearResult = const Right(unit);
  final patches = <UserSettingsPatch>[];
  int clearCalls = 0;

  @override
  Future<Either<Failure, UserSettings>> getSettings() async => settingsResult;

  @override
  Future<Either<Failure, UserSettings>> updateSettings(UserSettingsPatch patch) async {
    patches.add(patch);
    if (updateResult case final result?) return result;
    final current = settingsResult.getOrElse((_) => const UserSettings());
    final next = current.copyWith(
      language: patch.language ?? current.language,
      notifyPaymentReminders: patch.notifyPaymentReminders ?? current.notifyPaymentReminders,
      notifyDrawResults: patch.notifyDrawResults ?? current.notifyDrawResults,
      notifyGroupActivity: patch.notifyGroupActivity ?? current.notifyGroupActivity,
    );
    settingsResult = Right(next);
    return Right(next);
  }

  @override
  Future<Either<Failure, Unit>> clearImageCache() async {
    clearCalls++;
    return clearResult;
  }
}

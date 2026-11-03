import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasource/settings_local_data_source.dart';
import '../datasource/settings_local_data_source_impl.dart';
import '../datasource/settings_remote_data_source.dart';
import '../datasource/settings_remote_data_source_impl.dart';
import '../mappers/settings_mapper.dart';

part 'settings_repository_impl.g.dart';

class SettingsRepositoryImpl(
  final SettingsRemoteDataSource _remote,
  final SettingsLocalDataSource _local,
) with BaseRepository implements SettingsRepository {
  @override
  Future<Either<Failure, UserSettings>> getSettings() => safeCall(() async {
    final settings = await _remote.getSettings();
    return settings.toEntity();
  });

  @override
  Future<Either<Failure, UserSettings>> updateSettings(UserSettingsPatch patch) => safeCall(() async {
    final settings = await _remote.updateSettings(patch.toRequest());
    return settings.toEntity();
  });

  @override
  Future<Either<Failure, Unit>> clearImageCache() => safeCall(() async {
    await _local.clearImageCache();
    return unit;
  });
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) => SettingsRepositoryImpl(
  ref.watch(settingsRemoteDataSourceProvider),
  ref.watch(settingsLocalDataSourceProvider),
);

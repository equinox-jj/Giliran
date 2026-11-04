import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/exceptions.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/settings/data/datasource/model/user_settings_model.dart';
import 'package:giliran/features/settings/data/datasource/settings_local_data_source.dart';
import 'package:giliran/features/settings/data/datasource/settings_remote_data_source.dart';
import 'package:giliran/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:giliran/features/settings/domain/entities/user_settings.dart';

/// Answers with [settings], or throws [error] when set.
class _FakeRemote() implements SettingsRemoteDataSource {
  UserSettingsModel settings = const UserSettingsModel(
    language: 'id',
    notifyPaymentReminders: true,
    notifyDrawResults: false,
    notifyGroupActivity: true,
  );
  AppException? error;

  @override
  Future<UserSettingsModel> getSettings() async {
    if (error case final e?) throw e;
    return settings;
  }

  @override
  Future<UserSettingsModel> updateSettings(UpdateSettingsRequestModel body) async {
    if (error case final e?) throw e;
    settings = settings.copyWith(notifyDrawResults: body.notifyDrawResults ?? settings.notifyDrawResults);
    return settings;
  }
}

/// Holds the saved settings in memory; [failSave] makes saving throw.
class _FakeLocal() implements SettingsLocalDataSource {
  UserSettingsModel? saved;
  bool failSave = false;

  @override
  Future<UserSettingsModel?> readSettings() async => saved;

  @override
  Future<void> saveSettings(UserSettingsModel settings) async {
    if (failSave) throw const CacheException('disk full');
    saved = settings;
  }

  @override
  Future<void> clearImageCache() async {}
}

void main() {
  late _FakeRemote remote;
  late _FakeLocal local;
  late SettingsRepositoryImpl repository;

  setUp(() {
    remote = _FakeRemote();
    local = _FakeLocal();
    repository = SettingsRepositoryImpl(remote, local);
  });

  test('getCachedSettings is null when nothing is saved', () async {
    // Arrange
    local.saved = null;

    // Act
    final result = await repository.getCachedSettings();

    // Assert
    expect(result, const Right<Failure, UserSettings?>(null));
  });

  test('getSettings saves the server copy for the next open', () async {
    // Arrange
    local.saved = null;

    // Act
    await repository.getSettings();
    final cached = await repository.getCachedSettings();

    // Assert
    expect(local.saved, remote.settings);
    expect(cached.getRight().toNullable()?.notifyGroupActivity, isTrue);
  });

  test('updateSettings saves the server answer', () async {
    // Arrange
    const patch = UserSettingsPatch(notifyDrawResults: true);

    // Act
    final result = await repository.updateSettings(patch);

    // Assert
    expect(result.getRight().toNullable()?.notifyDrawResults, isTrue);
    expect(local.saved?.notifyDrawResults, isTrue);
  });

  test('a failed save still returns the server copy', () async {
    // Arrange
    local.failSave = true;

    // Act
    final result = await repository.getSettings();

    // Assert
    expect(result.isRight(), isTrue);
    expect(local.saved, isNull);
  });

  test('a failed fetch leaves the saved copy alone', () async {
    // Arrange
    const saved = UserSettingsModel(notifyDrawResults: true);
    local.saved = saved;
    remote.error = const NetworkException();

    // Act
    final result = await repository.getSettings();

    // Assert
    expect(result, const Left<Failure, UserSettings>(Failure.network()));
    expect(local.saved, saved);
  });
}

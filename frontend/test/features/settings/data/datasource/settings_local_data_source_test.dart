import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/features/settings/data/datasource/model/user_settings_model.dart';
import 'package:giliran/features/settings/data/datasource/settings_local_data_source_impl.dart';

import '../../../../helpers/fake_preferences.dart';

/// Never used by these tests; only `clearImageCache` touches the cache.
class _UnusedCacheManager() implements BaseCacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _settings = UserSettingsModel(
  language: 'en',
  notifyPaymentReminders: true,
  notifyDrawResults: false,
  notifyGroupActivity: true,
);

void main() {
  late FakePreferences prefs;
  late SettingsLocalDataSourceImpl dataSource;

  setUp(() {
    prefs = FakePreferences();
    dataSource = SettingsLocalDataSourceImpl(_UnusedCacheManager(), prefs);
  });

  test('readSettings is null when nothing is saved', () async {
    // Arrange
    prefs.userSettings = null;

    // Act
    final settings = await dataSource.readSettings();

    // Assert
    expect(settings, isNull);
  });

  test('saved settings read back unchanged', () async {
    // Arrange
    await dataSource.saveSettings(_settings);

    // Act
    final settings = await dataSource.readSettings();

    // Assert
    expect(settings, _settings);
  });

  test('a value that is not JSON reads as null and is cleared', () async {
    // Arrange
    prefs.userSettings = 'not json';

    // Act
    final settings = await dataSource.readSettings();

    // Assert
    expect(settings, isNull);
    expect(prefs.userSettings, isNull);
  });

  test('a field of the wrong type reads as null and is cleared', () async {
    // Arrange
    prefs.userSettings = '{"notify_draw_results": "yes"}';

    // Act
    final settings = await dataSource.readSettings();

    // Assert
    expect(settings, isNull);
    expect(prefs.userSettings, isNull);
  });
}

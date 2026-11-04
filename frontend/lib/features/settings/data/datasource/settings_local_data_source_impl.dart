import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_local_data_source.dart';
import '../../../../core/storage/preferences.dart';
import 'model/user_settings_model.dart';
import 'settings_local_data_source.dart';

part 'settings_local_data_source_impl.g.dart';

class SettingsLocalDataSourceImpl(final BaseCacheManager _cache, final Preferences _prefs)
    with BaseLocalDataSource
    implements SettingsLocalDataSource {
  @override
  Future<UserSettingsModel?> readSettings() => safeCacheCall(() async {
    final raw = await _prefs.readUserSettings();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return UserSettingsModel.fromJson(decoded);
    } on FormatException {
      // Not JSON: cleared below.
    } on TypeError {
      // A field of the wrong type: cleared below.
    }
    await _prefs.saveUserSettings(null);
    return null;
  });

  @override
  Future<void> saveSettings(UserSettingsModel settings) => safeCacheCall(
    () => _prefs.saveUserSettings(jsonEncode(settings.toJson())),
  );

  @override
  Future<void> clearImageCache() => safeCacheCall(() async {
    // `cached_network_image` stores its files in the default cache manager.
    await _cache.emptyCache();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });
}

@Riverpod(keepAlive: true)
SettingsLocalDataSource settingsLocalDataSource(Ref ref) => SettingsLocalDataSourceImpl(
  DefaultCacheManager(),
  ref.watch(preferencesProvider),
);

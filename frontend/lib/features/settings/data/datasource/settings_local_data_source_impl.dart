import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_local_data_source.dart';
import 'settings_local_data_source.dart';

part 'settings_local_data_source_impl.g.dart';

class SettingsLocalDataSourceImpl(final BaseCacheManager _cache)
    with BaseLocalDataSource
    implements SettingsLocalDataSource {
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
SettingsLocalDataSource settingsLocalDataSource(Ref ref) => SettingsLocalDataSourceImpl(DefaultCacheManager());

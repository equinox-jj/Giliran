import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_info_service.g.dart';

class DeviceInfoService(final DeviceInfoPlugin _plugin) {
  String? _cachedName;

  /// API `device_platform`: `android` or `ios`.
  String get platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// API `device_name` (max 100 chars), such as "samsung SM-A546E" or
  /// "iPhone 15". Falls back to the platform name if the plugin fails.
  Future<String> deviceName() async {
    if (_cachedName case final name?) return name;
    String name;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await _plugin.iosInfo;
        name = ios.modelName.isNotEmpty ? ios.modelName : ios.model;
      } else {
        final android = await _plugin.androidInfo;
        name = '${android.manufacturer} ${android.model}'.trim();
      }
    } on Exception {
      name = '';
    }
    if (name.isEmpty) name = platform == 'ios' ? 'iPhone' : 'Android';
    if (name.length > 100) name = name.substring(0, 100);
    return _cachedName = name;
  }
}

@Riverpod(keepAlive: true)
DeviceInfoService deviceInfoService(Ref ref) => DeviceInfoService(DeviceInfoPlugin());

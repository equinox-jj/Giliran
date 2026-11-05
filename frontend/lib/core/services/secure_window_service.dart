import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/logger/app_logger.dart';

part 'secure_window_service.g.dart';

/// Turns Android's `FLAG_SECURE` on or off for the app window, through the
/// `giliran/secure_window` channel in `MainActivity`. A secure window shows
/// blank in recent apps and blocks screenshots, which backs up the
/// privacy cover. Does nothing on other platforms.
class const SecureWindowService() {
  static const _channel = MethodChannel('giliran/secure_window');
  static const _tag = 'secure_window';

  Future<void> setSecure(bool secure) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on PlatformException catch (e) {
      AppLogger.w('setSecure failed: $e', tag: _tag);
    } on MissingPluginException catch (e) {
      // No channel (tests, or an engine without MainActivity).
      AppLogger.w('setSecure unavailable: $e', tag: _tag);
    }
  }
}

@Riverpod(keepAlive: true)
SecureWindowService secureWindowService(Ref ref) => const SecureWindowService();

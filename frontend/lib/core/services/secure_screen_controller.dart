import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/preferences.dart';
import 'secure_window_service.dart';

part 'secure_screen_controller.g.dart';

/// The S47 "Sembunyikan layar di app terbaru" choice, stored on the device.
///
/// `GiliranApp` watches it so the saved choice is applied to the window at
/// start; the settings toggle calls [set].
@Riverpod(keepAlive: true)
class SecureScreenController() extends _$SecureScreenController {
  @override
  Future<bool> build() async {
    final secure = await ref.read(preferencesProvider).readSecureScreen();
    // The window starts unsecured, so only an "on" needs applying.
    if (secure) await ref.read(secureWindowServiceProvider).setSecure(true);
    return secure;
  }

  Future<void> set(bool secure) async {
    state = AsyncData(secure);
    await ref.read(preferencesProvider).saveSecureScreen(secure);
    await ref.read(secureWindowServiceProvider).setSecure(secure);
  }
}

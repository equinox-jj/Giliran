import 'package:giliran/core/services/secure_window_service.dart';

/// Records [setSecure] calls instead of reaching the Android window.
class FakeSecureWindowService() implements SecureWindowService {
  final calls = <bool>[];

  @override
  Future<void> setSecure(bool secure) async => calls.add(secure);
}

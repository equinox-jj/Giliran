import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/user_settings.dart';

/// Account settings on the server and device-only settings data.
abstract interface class SettingsRepository() {
  /// The settings last saved on this device, or null when there are none.
  Future<Either<Failure, UserSettings?>> getCachedSettings();

  /// `GET /me/settings`, saved on this device for the next open.
  Future<Either<Failure, UserSettings>> getSettings();

  /// `PATCH /me/settings` with only the fields set in [patch]; the answer is
  /// saved on this device.
  Future<Either<Failure, UserSettings>> updateSettings(UserSettingsPatch patch);

  /// Empties the cached images on this device.
  Future<Either<Failure, Unit>> clearImageCache();
}

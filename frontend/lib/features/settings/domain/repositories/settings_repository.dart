import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/user_settings.dart';

/// Account settings on the server and device-only settings data.
abstract interface class SettingsRepository() {
  /// `GET /me/settings`.
  Future<Either<Failure, UserSettings>> getSettings();

  /// `PATCH /me/settings` with only the fields set in [patch].
  Future<Either<Failure, UserSettings>> updateSettings(UserSettingsPatch patch);

  /// Empties the cached images on this device.
  Future<Either<Failure, Unit>> clearImageCache();
}

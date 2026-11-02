import '../../../profile/data/datasource/model/profile_model.dart';
import 'model/email_otp_challenge_model.dart';
import 'model/token_pair_model.dart';

/// On-device auth state: tokens, the cached user, an unfinished code request
/// and the biometric flags.
///
/// Every method throws `CacheException` on failure.
abstract interface class AuthLocalDataSource {
  /// Stores a token pair from verify. Throws when either token is missing.
  Future<void> saveTokens(TokenPairModel tokens);

  /// Whether a refresh token is stored, meaning a session may still exist.
  Future<bool> hasRefreshToken();

  /// The cached signed-in user, or null when none (or unreadable).
  Future<ProfileDataModel?> readCurrentUser();

  Future<void> saveCurrentUser(ProfileDataModel user);

  /// The unfinished code request, or null when none (or unreadable).
  Future<PendingOtpModel?> readPendingOtp();

  Future<void> savePendingOtp(PendingOtpModel pending);

  Future<void> clearPendingOtp();

  /// Removes tokens, the cached user and any pending code request.
  Future<void> clearSession();

  Future<bool> readBiometricEnabled();

  Future<void> saveBiometricEnabled(bool enabled);

  Future<bool> readBiometricPrompted();

  Future<void> saveBiometricPrompted(bool prompted);
}

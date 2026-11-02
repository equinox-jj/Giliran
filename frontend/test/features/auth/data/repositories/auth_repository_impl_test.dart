import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/exceptions.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/error/problem_details.dart';
import 'package:giliran/core/services/device_info_service.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/data/datasource/auth_local_data_source.dart';
import 'package:giliran/features/auth/data/datasource/auth_remote_data_source.dart';
import 'package:giliran/features/auth/data/datasource/model/email_otp_challenge_model.dart';
import 'package:giliran/features/auth/data/datasource/model/email_otp_request_model.dart';
import 'package:giliran/features/auth/data/datasource/model/email_otp_result_model.dart';
import 'package:giliran/features/auth/data/datasource/model/email_otp_verify_request_model.dart';
import 'package:giliran/features/auth/data/datasource/model/pin_request_models.dart';
import 'package:giliran/features/auth/data/datasource/model/token_pair_model.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_challenge.dart';
import 'package:giliran/features/profile/data/datasource/model/profile_model.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';

/// Records each call and answers with the queued values, or throws [error].
class _FakeRemote implements AuthRemoteDataSource {
  Object? error;
  EmailOtpChallengeModel challenge = const EmailOtpChallengeModel(id: 'otp-1');
  EmailOtpResultModel result = const EmailOtpResultModel();

  final calls = <String>[];
  EmailOtpRequestModel? lastRequest;
  EmailOtpVerifyRequestModel? lastVerify;
  Object? lastPinBody;

  Future<T> _answer<T>(String name, T value) async {
    calls.add(name);
    if (error case final e?) throw e;
    return value;
  }

  @override
  Future<EmailOtpChallengeModel> requestEmailOtp(EmailOtpRequestModel body) {
    lastRequest = body;
    return _answer('requestEmailOtp', challenge);
  }

  @override
  Future<EmailOtpChallengeModel> resendEmailOtp(String otpId, {required OtpPurpose purpose}) =>
      _answer('resendEmailOtp:$otpId:${purpose.apiValue}', challenge);

  @override
  Future<EmailOtpResultModel> verifyEmailOtp(
    String otpId,
    EmailOtpVerifyRequestModel body, {
    required OtpPurpose purpose,
  }) {
    lastVerify = body;
    return _answer('verifyEmailOtp:$otpId:${purpose.apiValue}', result);
  }

  @override
  Future<void> setPin(SetPinRequestModel body) {
    lastPinBody = body;
    return _answer('setPin', null);
  }

  @override
  Future<void> changePin(ChangePinRequestModel body) {
    lastPinBody = body;
    return _answer('changePin', null);
  }

  @override
  Future<void> verifyPin(PinRequestModel body) {
    lastPinBody = body;
    return _answer('verifyPin', null);
  }

  @override
  Future<void> logout() => _answer('logout', null);
}

/// In-memory local store that can be made to throw [error].
class _FakeLocal implements AuthLocalDataSource {
  Object? error;
  TokenPairModel? tokens;
  ProfileDataModel? user;
  PendingOtpModel? pending;
  bool biometricEnabled = false;
  bool biometricPrompted = false;
  bool cleared = false;

  Future<T> _run<T>(T Function() body) async {
    if (error case final e?) throw e;
    return body();
  }

  @override
  Future<void> saveTokens(TokenPairModel tokens) => _run(() => this.tokens = tokens);

  @override
  Future<bool> hasRefreshToken() => _run(() => tokens?.refreshToken != null);

  @override
  Future<ProfileDataModel?> readCurrentUser() => _run(() => user);

  @override
  Future<void> saveCurrentUser(ProfileDataModel user) => _run(() => this.user = user);

  @override
  Future<PendingOtpModel?> readPendingOtp() => _run(() => pending);

  @override
  Future<void> savePendingOtp(PendingOtpModel pending) => _run(() => this.pending = pending);

  @override
  Future<void> clearPendingOtp() => _run(() => pending = null);

  @override
  Future<void> clearSession() => _run(() => cleared = true);

  @override
  Future<bool> readBiometricEnabled() => _run(() => biometricEnabled);

  @override
  Future<void> saveBiometricEnabled(bool enabled) => _run(() => biometricEnabled = enabled);

  @override
  Future<bool> readBiometricPrompted() => _run(() => biometricPrompted);

  @override
  Future<void> saveBiometricPrompted(bool prompted) => _run(() => biometricPrompted = prompted);
}

class _FakeDeviceInfo extends DeviceInfoService {
  _FakeDeviceInfo() : super(DeviceInfoPlugin());

  @override
  String get platform => 'android';

  @override
  Future<String> deviceName() async => 'samsung SM-A546E';
}

const _tokens = TokenPairModel(accessToken: 'access', refreshToken: 'refresh');
const _userModel = ProfileDataModel(id: 'u-1', email: 'jo@email.com');

void main() {
  late _FakeRemote remote;
  late _FakeLocal local;
  late AuthRepositoryImpl repository;

  setUp(() {
    remote = _FakeRemote();
    local = _FakeLocal();
    repository = AuthRepositoryImpl(remote: remote, local: local, deviceInfo: _FakeDeviceInfo());
  });

  group('requestEmailOtp', () {
    test('sends the device name and platform and returns the challenge', () async {
      // Arrange
      remote.challenge = const EmailOtpChallengeModel(id: 'otp-1', codeLength: 6);

      // Act
      final result = await repository.requestEmailOtp(purpose: OtpPurpose.signIn, email: 'jo@email.com');

      // Assert
      expect(result, const Right<Failure, EmailOtpChallenge>(EmailOtpChallenge(id: 'otp-1', codeLength: 6)));
      expect(
        remote.lastRequest,
        const EmailOtpRequestModel(
          purpose: OtpPurpose.signIn,
          email: 'jo@email.com',
          deviceName: 'samsung SM-A546E',
          devicePlatform: 'android',
        ),
      );
    });

    test('turns a network error into a NetworkFailure', () async {
      // Arrange
      remote.error = const NetworkException();

      // Act
      final result = await repository.requestEmailOtp(purpose: OtpPurpose.signIn, email: 'jo@email.com');

      // Assert
      expect(result, const Left<Failure, EmailOtpChallenge>(Failure.network()));
    });
  });

  group('resendEmailOtp', () {
    test('passes the id and purpose', () async {
      // Arrange
      remote.challenge = const EmailOtpChallengeModel(id: 'otp-2');

      // Act
      final result = await repository.resendEmailOtp('otp-1', purpose: OtpPurpose.resetPin);

      // Assert
      expect(result.getRight().toNullable()?.id, 'otp-2');
      expect(remote.calls, ['resendEmailOtp:otp-1:reset_pin']);
    });
  });

  group('verifyEmailOtp', () {
    test('stores the tokens and user when the result starts a session', () async {
      // Arrange
      remote.result = const EmailOtpResultModel(
        purpose: OtpPurpose.signIn,
        auth: AuthResultModel(user: _userModel, tokens: _tokens, isNewUser: false, pinSet: true),
      );

      // Act
      final result = await repository.verifyEmailOtp(
        'otp-1',
        purpose: OtpPurpose.signIn,
        code: '123456',
        pin: '112233',
      );

      // Assert
      final entity = result.getRight().toNullable();
      expect(entity?.auth?.user?.id, 'u-1');
      expect(entity?.auth?.pinSet, isTrue);
      expect(local.tokens, _tokens);
      expect(local.user, _userModel);
      expect(remote.lastVerify, const EmailOtpVerifyRequestModel(code: '123456', pin: '112233'));
    });

    test('stores nothing for a change_email result', () async {
      // Arrange
      remote.result = const EmailOtpResultModel(purpose: OtpPurpose.changeEmail, user: _userModel);

      // Act
      final result = await repository.verifyEmailOtp('otp-1', purpose: OtpPurpose.changeEmail, code: '123456');

      // Assert
      expect(result.getRight().toNullable()?.user?.id, 'u-1');
      expect(local.tokens, isNull);
      expect(local.user, isNull);
    });

    test('returns pin_required as a failure and stores nothing', () async {
      // Arrange
      remote.error = const ValidationException(
        problem: ProblemDetails(status: 422, code: ApiErrorCode.pinRequired, rawCode: 'pin_required'),
      );

      // Act
      final result = await repository.verifyEmailOtp('otp-1', purpose: OtpPurpose.signIn, code: '123456');

      // Assert
      expect(result.getLeft().toNullable()?.apiCode, ApiErrorCode.pinRequired);
      expect(local.tokens, isNull);
    });

    test('turns a storage error into a CacheFailure', () async {
      // Arrange
      remote.result = const EmailOtpResultModel(auth: AuthResultModel(tokens: _tokens));
      local.error = const CacheException('disk full');

      // Act
      final result = await repository.verifyEmailOtp('otp-1', purpose: OtpPurpose.signIn, code: '123456');

      // Assert
      expect(result.getLeft().toNullable(), isA<CacheFailure>());
    });
  });

  group('PIN', () {
    test('setPin sends the pin and confirmation', () async {
      // Act
      final result = await repository.setPin(pin: '112233', pinConfirmation: '112233');

      // Assert
      expect(result, const Right<Failure, Unit>(unit));
      expect(remote.lastPinBody, const SetPinRequestModel(pin: '112233', pinConfirmation: '112233'));
    });

    test('changePin sends the current and new pin', () async {
      // Act
      await repository.changePin(currentPin: '112233', newPin: '445566', newPinConfirmation: '445566');

      // Assert
      expect(
        remote.lastPinBody,
        const ChangePinRequestModel(currentPin: '112233', newPin: '445566', newPinConfirmation: '445566'),
      );
    });

    test('verifyPin sends the pin', () async {
      // Act
      await repository.verifyPin('112233');

      // Assert
      expect(remote.lastPinBody, const PinRequestModel(pin: '112233'));
    });
  });

  group('session', () {
    test('logout calls the server only', () async {
      // Act
      final result = await repository.logout();

      // Assert
      expect(result.isRight(), isTrue);
      expect(remote.calls, ['logout']);
      expect(local.cleared, isFalse);
    });

    test('clearSession clears local state', () async {
      // Act
      await repository.clearSession();

      // Assert
      expect(local.cleared, isTrue);
    });

    test('hasSession reflects the stored refresh token', () async {
      // Arrange
      local.tokens = _tokens;

      // Act
      final result = await repository.hasSession();

      // Assert
      expect(result, const Right<Failure, bool>(true));
    });

    test('saves and reads the current user as an entity', () async {
      // Arrange
      final user = ProfileData(id: 'u-1', email: 'jo@email.com');

      // Act
      await repository.saveCurrentUser(user);
      final result = await repository.readCurrentUser();

      // Assert
      expect(local.user, _userModel);
      expect(result.getRight().toNullable(), user);
    });
  });

  group('pending OTP', () {
    test('saves, reads and clears', () async {
      // Arrange
      const pending = PendingOtp(
        email: 'jo@email.com',
        challenge: EmailOtpChallenge(id: 'otp-1'),
      );

      // Act
      await repository.savePendingOtp(pending);
      final read = await repository.readPendingOtp();
      await repository.clearPendingOtp();

      // Assert
      expect(read.getRight().toNullable(), pending);
      expect(local.pending, isNull);
    });
  });

  group('biometric flags', () {
    test('saves and reads both flags', () async {
      // Act
      await repository.saveBiometricEnabled(true);
      await repository.saveBiometricPrompted(true);
      final enabled = await repository.readBiometricEnabled();
      final prompted = await repository.readBiometricPrompted();

      // Assert
      expect(enabled, const Right<Failure, bool>(true));
      expect(prompted, const Right<Failure, bool>(true));
    });

    test('turns a storage error into a CacheFailure', () async {
      // Arrange
      local.error = const CacheException();

      // Act
      final result = await repository.readBiometricEnabled();

      // Assert
      expect(result.getLeft().toNullable(), isA<CacheFailure>());
    });
  });
}

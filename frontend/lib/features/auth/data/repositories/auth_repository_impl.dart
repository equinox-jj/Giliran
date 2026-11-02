import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/services/device_info_service.dart';
import '../../../../core/utils/enums/otp_purpose.dart';
import '../../../profile/data/mapper/profile_mapper.dart';
import '../../../profile/domain/entity/profile.dart';
import '../../domain/entities/email_otp_challenge.dart';
import '../../domain/entities/email_otp_result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasource/auth_local_data_source.dart';
import '../datasource/auth_local_data_source_impl.dart';
import '../datasource/auth_remote_data_source.dart';
import '../datasource/auth_remote_data_source_impl.dart';
import '../datasource/model/email_otp_request_model.dart';
import '../datasource/model/email_otp_verify_request_model.dart';
import '../datasource/model/pin_request_models.dart';
import '../mappers/auth_mapper.dart';

part 'auth_repository_impl.g.dart';

class AuthRepositoryImpl({
  required final AuthRemoteDataSource _remote,
  required final AuthLocalDataSource _local,
  required final DeviceInfoService _deviceInfo,
}) with BaseRepository implements AuthRepository {
  @override
  Future<Either<Failure, EmailOtpChallenge>> requestEmailOtp({
    required OtpPurpose purpose,
    required String email,
    String? pin,
  }) => safeCall(() async {
    // fcm_token stays null until push notifications are wired up.
    final challenge = await _remote.requestEmailOtp(
      EmailOtpRequestModel(
        purpose: purpose,
        email: email,
        deviceName: await _deviceInfo.deviceName(),
        devicePlatform: _deviceInfo.platform,
        pin: pin,
      ),
    );

    return challenge.toEntity();
  });

  @override
  Future<Either<Failure, EmailOtpChallenge>> resendEmailOtp(
    String otpId, {
    required OtpPurpose purpose,
  }) => safeCall(() async {
    final challenge = await _remote.resendEmailOtp(
      otpId,
      purpose: purpose,
    );

    return challenge.toEntity();
  });

  @override
  Future<Either<Failure, EmailOtpResult>> verifyEmailOtp(
    String otpId, {
    required OtpPurpose purpose,
    required String code,
    String? pin,
    String? newPin,
    String? newPinConfirmation,
  }) => safeCall(() async {
    final result = await _remote.verifyEmailOtp(
      otpId,
      EmailOtpVerifyRequestModel(
        code: code,
        pin: pin,
        newPin: newPin,
        newPinConfirmation: newPinConfirmation,
      ),
      purpose: purpose,
    );
    // Tokens never leave the data layer, so they are stored here.
    if (result.auth?.tokens case final tokens?) {
      await _local.saveTokens(tokens);
      if (result.auth?.user case final user?) {
        await _local.saveCurrentUser(user);
      }
    }

    return result.toEntity();
  });

  @override
  Future<Either<Failure, Unit>> setPin({
    required String pin,
    required String pinConfirmation,
  }) => safeCall(() async {
    await _remote.setPin(
      SetPinRequestModel(pin: pin, pinConfirmation: pinConfirmation),
    );

    return unit;
  });

  @override
  Future<Either<Failure, Unit>> changePin({
    required String currentPin,
    required String newPin,
    required String newPinConfirmation,
  }) => safeCall(() async {
    await _remote.changePin(
      ChangePinRequestModel(
        currentPin: currentPin,
        newPin: newPin,
        newPinConfirmation: newPinConfirmation,
      ),
    );

    return unit;
  });

  @override
  Future<Either<Failure, Unit>> verifyPin(String pin) => safeCall(() async {
    await _remote.verifyPin(PinRequestModel(pin: pin));

    return unit;
  });

  @override
  Future<Either<Failure, Unit>> logout() => safeCall(() async {
    await _remote.logout();

    return unit;
  });

  @override
  Future<Either<Failure, Unit>> clearSession() => safeCall(() async {
    await _local.clearSession();

    return unit;
  });

  @override
  Future<Either<Failure, bool>> hasSession() => safeCall(_local.hasRefreshToken);

  @override
  Future<Either<Failure, ProfileData?>> readCurrentUser() => safeCall(
    () async => (await _local.readCurrentUser())?.toEntity(),
  );

  @override
  Future<Either<Failure, Unit>> saveCurrentUser(ProfileData user) => safeCall(() async {
    await _local.saveCurrentUser(user.toModel());

    return unit;
  });

  @override
  Future<Either<Failure, PendingOtp?>> readPendingOtp() => safeCall(
    () async => (await _local.readPendingOtp())?.toEntity(),
  );

  @override
  Future<Either<Failure, Unit>> savePendingOtp(PendingOtp pending) => safeCall(() async {
    await _local.savePendingOtp(pending.toModel());

    return unit;
  });

  @override
  Future<Either<Failure, Unit>> clearPendingOtp() => safeCall(() async {
    await _local.clearPendingOtp();

    return unit;
  });

  @override
  Future<Either<Failure, bool>> readBiometricEnabled() => safeCall(_local.readBiometricEnabled);

  @override
  Future<Either<Failure, Unit>> saveBiometricEnabled(bool enabled) => safeCall(() async {
    await _local.saveBiometricEnabled(enabled);

    return unit;
  });

  @override
  Future<Either<Failure, bool>> readBiometricPrompted() => safeCall(_local.readBiometricPrompted);

  @override
  Future<Either<Failure, Unit>> saveBiometricPrompted(bool prompted) => safeCall(() async {
    await _local.saveBiometricPrompted(prompted);

    return unit;
  });
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepositoryImpl(
  remote: ref.watch(authRemoteDataSourceProvider),
  local: ref.watch(authLocalDataSourceProvider),
  deviceInfo: ref.watch(deviceInfoServiceProvider),
);

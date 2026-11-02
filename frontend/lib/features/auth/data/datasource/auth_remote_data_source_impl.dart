import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_remote_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/enums/otp_purpose.dart';
import 'auth_remote_data_source.dart';
import 'model/email_otp_challenge_model.dart';
import 'model/email_otp_request_model.dart';
import 'model/email_otp_result_model.dart';
import 'model/email_otp_verify_request_model.dart';
import 'model/pin_request_models.dart';

part 'auth_remote_data_source_impl.g.dart';

class AuthRemoteDataSourceImpl(final Dio _dio) with BaseRemoteDataSource implements AuthRemoteDataSource {
  @override
  Future<EmailOtpChallengeModel> requestEmailOtp(EmailOtpRequestModel body) => safeApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.emailOtp,
      data: body.toJson(),
      options: _options(body.purpose),
    );
    return _data(response, EmailOtpChallengeModel.fromJson);
  });

  @override
  Future<EmailOtpChallengeModel> resendEmailOtp(
    String otpId, {
    required OtpPurpose purpose,
  }) => safeApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.emailOtpResend(otpId),
      options: _options(purpose),
    );
    return _data(response, EmailOtpChallengeModel.fromJson);
  });

  @override
  Future<EmailOtpResultModel> verifyEmailOtp(
    String otpId,
    EmailOtpVerifyRequestModel body, {
    required OtpPurpose purpose,
  }) => safeApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.emailOtpVerify(otpId),
      data: body.toJson(),
      options: _options(purpose),
    );
    return _data(response, EmailOtpResultModel.fromJson);
  });

  @override
  Future<void> setPin(SetPinRequestModel body) => safeApiCall(() async {
    await _dio.post<void>(ApiEndpoints.pin, data: body.toJson());
  });

  @override
  Future<void> changePin(ChangePinRequestModel body) => safeApiCall(() async {
    await _dio.put<void>(ApiEndpoints.pin, data: body.toJson());
  });

  @override
  Future<void> verifyPin(PinRequestModel body) => safeApiCall(() async {
    await _dio.post<void>(ApiEndpoints.pinVerify, data: body.toJson());
  });

  @override
  Future<void> logout() => safeApiCall(() async {
    await _dio.post<void>(ApiEndpoints.logout);
  });

  /// Only `change_email` runs inside a session. `sign_in` and `reset_pin`
  /// skip the token so a stale one can't trigger a refresh.
  Options _options(OtpPurpose? purpose) => Options(
    extra: {ApiEndpoints.kNoAuth: purpose != OtpPurpose.changeEmail},
  );

  /// Unwraps the `{"data": …}` envelope; a missing `data` is a malformed body.
  T _data<T>(
    Response<Map<String, dynamic>> response,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final body = response.data;
    final data = body == null
        ? null
        : ApiResponse<T>.fromJson(
            body,
            (json) => fromJson(json! as Map<String, dynamic>),
          ).data;
    if (data == null) {
      throw UnknownException('Empty response from ${response.realUri.path}');
    }
    return data;
  }
}

@Riverpod(keepAlive: true)
AuthRemoteDataSource authRemoteDataSource(Ref ref) => AuthRemoteDataSourceImpl(
  ref.watch(dioProvider),
);

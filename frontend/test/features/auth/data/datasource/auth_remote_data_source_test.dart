import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/exceptions.dart';
import 'package:giliran/core/network/api_endpoints.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/data/datasource/auth_remote_data_source_impl.dart';
import 'package:giliran/features/auth/data/datasource/model/email_otp_request_model.dart';
import 'package:giliran/features/auth/data/datasource/model/email_otp_verify_request_model.dart';
import 'package:giliran/features/auth/data/datasource/model/pin_request_models.dart';

/// Records each request and answers with the queued [status], [body] and
/// [headers].
class _RecordingAdapter implements HttpClientAdapter {
  int status = 200;
  Object? body;
  Map<String, List<String>> headers = const {};

  final requests = <RequestOptions>[];

  RequestOptions get last => requests.last;

  /// The JSON body of the last request, or null when it had none.
  Map<String, dynamic>? get lastBody => last.data as Map<String, dynamic>?;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final contentType = status >= 400 ? 'application/problem+json' : Headers.jsonContentType;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [contentType],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _challengeJson = {
  'id': 'otp-1',
  'purpose': 'sign_in',
  'email_masked': 'jo•••••@email.com',
  'code_length': 6,
  'expires_at': '2026-11-02T08:10:00Z',
  'resend_available_at': '2026-11-02T08:01:00Z',
  'attempts_remaining': 5,
};

const _userJson = {
  'id': 'user-1',
  'email': 'joshua@email.com',
  'phone': null,
  'name': null,
  'avatar_url': null,
  'pin_set': false,
  'created_at': '2026-11-02T08:00:00Z',
};

void main() {
  late _RecordingAdapter adapter;
  late AuthRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    dataSource = AuthRemoteDataSourceImpl(dio);
  });

  group('requestEmailOtp', () {
    test(
      'posts a sign_in request without auth and parses the challenge',
      () async {
        // Arrange
        adapter
          ..status = 202
          ..body = {'data': _challengeJson};
        const request = EmailOtpRequestModel(
          purpose: OtpPurpose.signIn,
          email: 'joshua@email.com',
          deviceName: 'samsung SM-A546E',
          devicePlatform: 'android',
        );

        // Act
        final challenge = await dataSource.requestEmailOtp(request);

        // Assert
        expect(adapter.last.method, 'POST');
        expect(adapter.last.path, '/auth/email/otp');
        expect(adapter.last.extra[ApiEndpoints.kNoAuth], isTrue);
        expect(adapter.lastBody, {
          'purpose': 'sign_in',
          'email': 'joshua@email.com',
          'device_name': 'samsung SM-A546E',
          'device_platform': 'android',
        });
        expect(challenge.id, 'otp-1');
        expect(challenge.purpose, OtpPurpose.signIn);
        expect(challenge.emailMasked, 'jo•••••@email.com');
        expect(challenge.expiresAt, DateTime.utc(2026, 11, 2, 8, 10));
        expect(challenge.resendAvailableAt, DateTime.utc(2026, 11, 2, 8, 1));
        expect(challenge.attemptsRemaining, 5);
      },
    );

    test('sends the access token for change_email', () async {
      // Arrange
      adapter
        ..status = 202
        ..body = {'data': _challengeJson};
      const request = EmailOtpRequestModel(
        purpose: OtpPurpose.changeEmail,
        email: 'new@email.com',
        pin: '482915',
      );

      // Act
      await dataSource.requestEmailOtp(request);

      // Assert
      expect(adapter.last.extra[ApiEndpoints.kNoAuth], isFalse);
      expect(adapter.lastBody?['pin'], '482915');
    });

    test('maps 429 to TooManyRequestsException with Retry-After', () async {
      // Arrange
      adapter
        ..status = 429
        ..body = {'status': 429, 'code': 'rate_limit_exceeded'}
        ..headers = {
          'retry-after': ['750'],
        };
      const request = EmailOtpRequestModel(
        purpose: OtpPurpose.signIn,
        email: 'joshua@email.com',
      );

      // Act
      final call = dataSource.requestEmailOtp(request);

      // Assert
      await expectLater(
        call,
        throwsA(
          isA<TooManyRequestsException>()
              .having((e) => e.code, 'code', ApiErrorCode.rateLimitExceeded)
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 750),
              ),
        ),
      );
    });

    test('throws UnknownException when the body has no data', () async {
      // Arrange
      adapter
        ..status = 202
        ..body = {'message': 'ok'};
      const request = EmailOtpRequestModel(purpose: OtpPurpose.signIn);

      // Act
      final call = dataSource.requestEmailOtp(request);

      // Assert
      await expectLater(call, throwsA(isA<UnknownException>()));
    });
  });

  group('resendEmailOtp', () {
    test('posts to the resend path and parses the new challenge', () async {
      // Arrange
      adapter
        ..status = 202
        ..body = {'data': _challengeJson};

      // Act
      final challenge = await dataSource.resendEmailOtp(
        'otp-1',
        purpose: OtpPurpose.signIn,
      );

      // Assert
      expect(adapter.last.method, 'POST');
      expect(adapter.last.path, '/auth/email/otp/otp-1/resend');
      expect(adapter.last.extra[ApiEndpoints.kNoAuth], isTrue);
      expect(challenge.id, 'otp-1');
    });
  });

  group('verifyEmailOtp', () {
    test('sends only the set fields and parses the auth result', () async {
      // Arrange
      adapter.body = {
        'data': {
          'purpose': 'sign_in',
          'auth': {
            'user': _userJson,
            'tokens': {
              'access_token': 'access',
              'refresh_token': 'refresh',
              'token_type': 'Bearer',
              'expires_in': 900,
            },
            'is_new_user': true,
            'pin_set': false,
          },
          'user': null,
        },
      };
      const body = EmailOtpVerifyRequestModel(code: '482915');

      // Act
      final result = await dataSource.verifyEmailOtp(
        'otp-1',
        body,
        purpose: OtpPurpose.signIn,
      );

      // Assert
      expect(adapter.last.path, '/auth/email/otp/otp-1/verify');
      expect(adapter.lastBody, {'code': '482915'});
      expect(result.purpose, OtpPurpose.signIn);
      expect(result.auth?.isNewUser, isTrue);
      expect(result.auth?.pinSet, isFalse);
      expect(result.auth?.user?.email, 'joshua@email.com');
      expect(result.auth?.user?.name, isNull);
      expect(result.auth?.tokens?.accessToken, 'access');
      expect(result.auth?.tokens?.refreshToken, 'refresh');
      expect(result.user, isNull);
    });

    test('maps 422 pin_required to ValidationException', () async {
      // Arrange
      adapter
        ..status = 422
        ..body = {'status': 422, 'code': 'pin_required'};
      const body = EmailOtpVerifyRequestModel(code: '482915');

      // Act
      final call = dataSource.verifyEmailOtp(
        'otp-1',
        body,
        purpose: OtpPurpose.signIn,
      );

      // Assert
      await expectLater(
        call,
        throwsA(
          isA<ValidationException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.pinRequired,
          ),
        ),
      );
    });

    test('keeps attempts_remaining on 422 otp_invalid', () async {
      // Arrange
      adapter
        ..status = 422
        ..body = {
          'status': 422,
          'code': 'otp_invalid',
          'attempts_remaining': 3,
        };
      const body = EmailOtpVerifyRequestModel(code: '000000');

      // Act
      final call = dataSource.verifyEmailOtp(
        'otp-1',
        body,
        purpose: OtpPurpose.signIn,
      );

      // Assert
      await expectLater(
        call,
        throwsA(
          isA<ValidationException>()
              .having((e) => e.code, 'code', ApiErrorCode.otpInvalid)
              .having(
                (e) => e.problem?.extensions['attempts_remaining'],
                'attempts_remaining',
                3,
              ),
        ),
      );
    });

    test('sends the new PIN fields for reset_pin', () async {
      // Arrange
      adapter.body = {
        'data': {'purpose': 'reset_pin'},
      };
      const body = EmailOtpVerifyRequestModel(
        code: '482915',
        newPin: '507193',
        newPinConfirmation: '507193',
      );

      // Act
      await dataSource.verifyEmailOtp(
        'otp-1',
        body,
        purpose: OtpPurpose.resetPin,
      );

      // Assert
      expect(adapter.last.extra[ApiEndpoints.kNoAuth], isTrue);
      expect(adapter.lastBody, {
        'code': '482915',
        'new_pin': '507193',
        'new_pin_confirmation': '507193',
      });
    });
  });

  group('PIN and logout', () {
    test('setPin posts both entries to /auth/pin', () async {
      // Arrange
      adapter.status = 204;

      // Act
      await dataSource.setPin(
        const SetPinRequestModel(pin: '507193', pinConfirmation: '507193'),
      );

      // Assert
      expect(adapter.last.method, 'POST');
      expect(adapter.last.path, '/auth/pin');
      expect(adapter.lastBody, {
        'pin': '507193',
        'pin_confirmation': '507193',
      });
    });

    test('changePin puts to /auth/pin', () async {
      // Arrange
      adapter.status = 204;

      // Act
      await dataSource.changePin(
        const ChangePinRequestModel(
          currentPin: '507193',
          newPin: '614028',
          newPinConfirmation: '614028',
        ),
      );

      // Assert
      expect(adapter.last.method, 'PUT');
      expect(adapter.last.path, '/auth/pin');
      expect(adapter.lastBody?['current_pin'], '507193');
    });

    test('verifyPin posts to /auth/pin/verify', () async {
      // Arrange
      adapter.status = 204;

      // Act
      await dataSource.verifyPin(const PinRequestModel(pin: '507193'));

      // Assert
      expect(adapter.last.method, 'POST');
      expect(adapter.last.path, '/auth/pin/verify');
      expect(adapter.lastBody, {'pin': '507193'});
    });

    test('verifyPin maps 423 pin_locked with Retry-After', () async {
      // Arrange
      adapter
        ..status = 423
        ..body = {'status': 423, 'code': 'pin_locked'}
        ..headers = {
          'retry-after': ['900'],
        };

      // Act
      final call = dataSource.verifyPin(const PinRequestModel(pin: '000000'));

      // Assert
      await expectLater(
        call,
        throwsA(
          isA<BadRequestException>()
              .having((e) => e.code, 'code', ApiErrorCode.pinLocked)
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(minutes: 15),
              ),
        ),
      );
    });

    test('verifyPin maps 401 pin_invalid to UnauthorizedException', () async {
      // Arrange
      adapter
        ..status = 401
        ..body = {
          'status': 401,
          'code': 'pin_invalid',
          'attempts_remaining': 2,
        };

      // Act
      final call = dataSource.verifyPin(const PinRequestModel(pin: '000000'));

      // Assert
      await expectLater(
        call,
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.pinInvalid,
          ),
        ),
      );
    });

    test('logout posts to /auth/logout with the token', () async {
      // Arrange
      adapter.status = 204;

      // Act
      await dataSource.logout();

      // Assert
      expect(adapter.last.method, 'POST');
      expect(adapter.last.path, '/auth/logout');
      expect(adapter.last.extra[ApiEndpoints.kNoAuth], isNot(isTrue));
    });
  });
}

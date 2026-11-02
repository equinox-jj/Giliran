import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/data/datasource/model/email_otp_challenge_model.dart';
import 'package:giliran/features/auth/data/datasource/model/email_otp_result_model.dart';
import 'package:giliran/features/auth/data/datasource/model/token_pair_model.dart';
import 'package:giliran/features/auth/data/mappers/auth_mapper.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_challenge.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_result.dart';
import 'package:giliran/features/profile/data/datasource/model/profile_model.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';

final _challengeModel = EmailOtpChallengeModel(
  id: 'otp-1',
  purpose: OtpPurpose.signIn,
  emailMasked: 'jo•••••@email.com',
  codeLength: 6,
  expiresAt: DateTime.utc(2026, 11, 2, 8, 10),
  resendAvailableAt: DateTime.utc(2026, 11, 2, 8, 1),
  attemptsRemaining: 5,
);

final _challenge = EmailOtpChallenge(
  id: 'otp-1',
  purpose: OtpPurpose.signIn,
  emailMasked: 'jo•••••@email.com',
  codeLength: 6,
  expiresAt: DateTime.utc(2026, 11, 2, 8, 10),
  resendAvailableAt: DateTime.utc(2026, 11, 2, 8, 1),
  attemptsRemaining: 5,
);

const _userModel = ProfileDataModel(id: 'u-1', email: 'jo@email.com', name: 'Jo', pinSet: true);

void main() {
  group('EmailOtpChallengeModel.toEntity', () {
    test('maps every field', () {
      // Arrange
      final model = _challengeModel;

      // Act
      final entity = model.toEntity();

      // Assert
      expect(entity, _challenge);
    });

    test('round-trips through toModel', () {
      // Arrange
      final entity = _challenge;

      // Act
      final model = entity.toModel();

      // Assert
      expect(model, _challengeModel);
    });
  });

  group('PendingOtpModel', () {
    test('maps the email and nested challenge', () {
      // Arrange
      final model = PendingOtpModel(email: 'jo@email.com', challenge: _challengeModel);

      // Act
      final entity = model.toEntity();

      // Assert
      expect(entity, PendingOtp(email: 'jo@email.com', challenge: _challenge));
    });

    test('keeps a missing challenge null', () {
      // Arrange
      const model = PendingOtpModel(email: 'jo@email.com');

      // Act
      final entity = model.toEntity();

      // Assert
      expect(entity.challenge, isNull);
    });

    test('round-trips through toModel', () {
      // Arrange
      final entity = PendingOtp(email: 'jo@email.com', challenge: _challenge);

      // Act
      final model = entity.toModel();

      // Assert
      expect(model, PendingOtpModel(email: 'jo@email.com', challenge: _challengeModel));
    });
  });

  group('EmailOtpResultModel.toEntity', () {
    test('maps auth without the tokens', () {
      // Arrange
      const model = EmailOtpResultModel(
        purpose: OtpPurpose.signIn,
        auth: AuthResultModel(
          user: _userModel,
          tokens: TokenPairModel(accessToken: 'a', refreshToken: 'r'),
          isNewUser: true,
          pinSet: false,
        ),
      );

      // Act
      final entity = model.toEntity();

      // Assert
      expect(
        entity,
        EmailOtpResult(
          purpose: OtpPurpose.signIn,
          auth: AuthResult(
            user: ProfileData(id: 'u-1', email: 'jo@email.com', name: 'Jo', pinSet: true),
            isNewUser: true,
            pinSet: false,
          ),
        ),
      );
    });

    test('maps the user of a change_email result', () {
      // Arrange
      const model = EmailOtpResultModel(purpose: OtpPurpose.changeEmail, user: _userModel);

      // Act
      final entity = model.toEntity();

      // Assert
      expect(entity.auth, isNull);
      expect(entity.user?.email, 'jo@email.com');
    });
  });
}

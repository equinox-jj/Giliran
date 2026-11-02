import '../../../profile/data/mapper/profile_mapper.dart';
import '../../domain/entities/email_otp_challenge.dart';
import '../../domain/entities/email_otp_result.dart';
import '../datasource/model/email_otp_challenge_model.dart';
import '../datasource/model/email_otp_result_model.dart';

extension EmailOtpChallengeModelMapper on EmailOtpChallengeModel {
  EmailOtpChallenge toEntity() {
    return EmailOtpChallenge(
      id: id,
      purpose: purpose,
      emailMasked: emailMasked,
      codeLength: codeLength,
      expiresAt: expiresAt,
      resendAvailableAt: resendAvailableAt,
      attemptsRemaining: attemptsRemaining,
    );
  }
}

extension PendingOtpModelMapper on PendingOtpModel {
  PendingOtp toEntity() {
    return PendingOtp(
      email: email,
      challenge: challenge?.toEntity(),
    );
  }
}

extension EmailOtpResultModelMapper on EmailOtpResultModel {
  EmailOtpResult toEntity() {
    return EmailOtpResult(
      purpose: purpose,
      auth: auth?.toEntity(),
      user: user?.toEntity(),
    );
  }
}

/// Drops the tokens: only the data layer stores them.
extension AuthResultModelMapper on AuthResultModel {
  AuthResult toEntity() {
    return AuthResult(
      user: user?.toEntity(),
      isNewUser: isNewUser,
      pinSet: pinSet,
    );
  }
}

extension EmailOtpChallengeEntityMapper on EmailOtpChallenge {
  EmailOtpChallengeModel toModel() {
    return EmailOtpChallengeModel(
      id: id,
      purpose: purpose,
      emailMasked: emailMasked,
      codeLength: codeLength,
      expiresAt: expiresAt,
      resendAvailableAt: resendAvailableAt,
      attemptsRemaining: attemptsRemaining,
    );
  }
}

extension PendingOtpEntityMapper on PendingOtp {
  PendingOtpModel toModel() {
    return PendingOtpModel(
      email: email,
      challenge: challenge?.toModel(),
    );
  }
}

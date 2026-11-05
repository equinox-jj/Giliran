import '../l10n/l10n.dart';
import '../utils/enums/api_error_code.dart';
import 'failure.dart';

/// Default message for any [Failure] variant, in the app's current language.
///
/// Screens that handle a specific `apiCode` (for example `otp_invalid` with
/// its attempts left) show their own copy instead.
extension FailureMessage on Failure {
  /// The fallback display message for this failure, read from [l10n]
  /// (`failure.displayMessage(context.l10n)`).
  String displayMessage(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.failureNetwork,
    TimeoutFailure() => l10n.failureTimeout,
    BadRequestFailure(code: ApiErrorCode.fileTooLarge) => l10n.failureFileTooLarge,
    BadRequestFailure(code: ApiErrorCode.unsupportedMediaType) => l10n.failureUnsupportedMedia,
    BadRequestFailure() => l10n.failureBadRequest,
    UnauthorizedFailure() => l10n.failureUnauthorized,
    ForbiddenFailure() => l10n.failureForbidden,
    NotFoundFailure() => l10n.failureNotFound,
    ConflictFailure(code: ApiErrorCode.drawTooEarly) => l10n.failureDrawTooEarly,
    ConflictFailure(code: ApiErrorCode.drawAlreadyDone) => l10n.failureDrawAlreadyDone,
    ConflictFailure(code: ApiErrorCode.paymentsIncomplete) => l10n.failurePaymentsIncomplete,
    ConflictFailure(code: ApiErrorCode.periodNotOpen) => l10n.failurePeriodNotOpen,
    ConflictFailure(code: ApiErrorCode.payoutAlreadyRecorded) => l10n.failurePayoutAlreadyRecorded,
    ConflictFailure() => l10n.failureConflict,
    ValidationFailure() => l10n.failureValidation,
    TooManyRequestsFailure() => l10n.failureTooManyRequests,
    ServerFailure() => l10n.failureServer,
    CacheFailure() => l10n.failureCache,
    UnknownFailure() => l10n.failureUnknown,
  };
}

import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';

/// `409` with [code].
Failure conflict(ApiErrorCode code) => Failure.conflict(code: code);

/// `404` with [code].
Failure notFound(ApiErrorCode code) => Failure.notFound(code: code);

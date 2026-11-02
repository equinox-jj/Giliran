import 'package:equatable/equatable.dart';

import '../utils/enums/api_error_code.dart';

/// An RFC 9457 Problem Details body (`application/problem+json`) with the
/// Giliran extensions `code`, `request_id` and `errors[]`.
///
/// Members outside the standard set, such as `attempts_remaining` or
/// `paid_count`, are kept in [extensions].
final class ProblemDetails extends Equatable {
  const ProblemDetails({
    this.type = 'about:blank',
    this.title = '',
    required this.status,
    this.detail,
    this.instance,
    required this.code,
    required this.rawCode,
    this.requestId,
    this.fieldErrors = const [],
    this.extensions = const {},
  });

  /// Parses a problem body. Missing members fall back to defaults so a
  /// partial body still yields a usable value.
  factory ProblemDetails.fromJson(Map<String, Object?> json) {
    final rawCode = json['code'] as String? ?? ApiErrorCode.unknown.apiValue;
    final errors = json['errors'];
    return ProblemDetails(
      type: json['type'] as String? ?? 'about:blank',
      title: json['title'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      detail: json['detail'] as String?,
      instance: json['instance'] as String?,
      code: ApiErrorCode.fromApi(rawCode),
      rawCode: rawCode,
      requestId: json['request_id'] as String?,
      fieldErrors: errors is List
          ? errors.whereType<Map<String, Object?>>().map(FieldError.fromJson).toList(growable: false)
          : const [],
      extensions: {
        for (final entry in json.entries)
          if (!_standardMembers.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  static const _standardMembers = {
    'type',
    'title',
    'status',
    'detail',
    'instance',
    'code',
    'request_id',
    'errors',
  };

  final String type;
  final String title;

  /// Matches the HTTP status code.
  final int status;

  /// Human-readable explanation. For logs only; never parse or branch on it.
  final String? detail;
  final String? instance;
  final ApiErrorCode code;

  /// The `code` as sent, kept when [code] is [ApiErrorCode.unknown].
  final String rawCode;

  /// Correlation id shown on the server-error card for support.
  final String? requestId;

  /// Field-level errors on `validation_error`.
  final List<FieldError> fieldErrors;
  final Map<String, Object?> extensions;

  /// Wrong OTP attempts left (`otp_invalid`).
  int? get attemptsRemaining => _int('attempts_remaining');

  /// Paid and total payments in the period (`payments_incomplete`).
  int? get paidCount => _int('paid_count');
  int? get totalCount => _int('total_count');

  int? _int(String key) => (extensions[key] as num?)?.toInt();

  @override
  List<Object?> get props => [
    type,
    title,
    status,
    detail,
    instance,
    rawCode,
    requestId,
    fieldErrors,
    extensions,
  ];
}

/// One entry of `errors[]` in a `validation_error` problem.
final class FieldError extends Equatable {
  const FieldError({
    required this.field,
    required this.code,
    required this.message,
  });

  factory FieldError.fromJson(Map<String, Object?> json) => FieldError(
    field: json['field'] as String? ?? '',
    code: json['code'] as String? ?? '',
    message: json['message'] as String? ?? '',
  );

  /// JSON path of the field, e.g. `amount` or `order[2].position`.
  final String field;

  /// `required`, `min_length`, `maximum_value`, …
  final String code;

  /// Indonesian copy from the server, shown under the matching form field.
  final String message;

  @override
  List<Object?> get props => [field, code, message];
}

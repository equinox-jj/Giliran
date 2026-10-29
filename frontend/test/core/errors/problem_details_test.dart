import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/errors/errors.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';

void main() {
  group('ProblemDetails.fromJson', () {
    test('parses a validation problem with errors[]', () {
      final problem = ProblemDetails.fromJson({
        'type': 'https://giliran.monai.my.id/problems/validation-error',
        'title': 'Validation failed',
        'status': 422,
        'detail': 'One or more fields are invalid.',
        'code': 'validation_error',
        'request_id': 'req_01JB8Z6X4Q',
        'errors': [
          {
            'field': 'amount',
            'code': 'minimum_value',
            'message': 'Iuran minimal Rp10.000.',
          },
        ],
      });

      expect(problem.code, ApiErrorCode.validationError);
      expect(problem.status, 422);
      expect(problem.requestId, 'req_01JB8Z6X4Q');
      expect(problem.fieldErrors, [
        const FieldError(
          field: 'amount',
          code: 'minimum_value',
          message: 'Iuran minimal Rp10.000.',
        ),
      ]);
      expect(problem.extensions, isEmpty);
    });

    test('keeps extension members', () {
      final problem = ProblemDetails.fromJson({
        'status': 409,
        'code': 'payments_incomplete',
        'paid_count': 8,
        'total_count': 10,
      });

      expect(problem.code, ApiErrorCode.paymentsIncomplete);
      expect(problem.paidCount, 8);
      expect(problem.totalCount, 10);
      expect(problem.type, 'about:blank');
    });

    test('maps an unknown code to unknown and keeps the raw code', () {
      final problem = ProblemDetails.fromJson({
        'status': 409,
        'code': 'something_new',
      });

      expect(problem.code, ApiErrorCode.unknown);
      expect(problem.rawCode, 'something_new');
    });
  });
}

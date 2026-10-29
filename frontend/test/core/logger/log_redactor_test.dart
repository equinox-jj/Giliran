import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/logger/logger.dart';

void main() {
  group('redact', () {
    test('replaces sensitive keys in nested maps and lists', () {
      final result = redact({
        'name': 'Sari',
        'pin': '482913',
        'Authorization': 'Bearer abc',
        'refreshToken': 'r-1',
        'payment_info': {'bank_name': 'BCA', 'account-number': '1234567890'},
        'members': [
          {'name': 'Budi', 'whatsapp': '081234567890'},
        ],
      });

      expect(result, {
        'name': 'Sari',
        'pin': redactedValue,
        'Authorization': redactedValue,
        'refreshToken': redactedValue,
        'payment_info': {'bank_name': 'BCA', 'account-number': redactedValue},
        'members': [
          {'name': 'Budi', 'whatsapp': redactedValue},
        ],
      });
    });

    test('keeps the API error code and plain values', () {
      expect(
        redact({'code': 'pin_locked', 'status': 423, 'amount': 100000}),
        {'code': 'pin_locked', 'status': 423, 'amount': 100000},
      );
    });

    test('scrubs strings inside collections', () {
      expect(redact(['mail sari@example.com']), ['mail «email»']);
    });
  });

  group('scrub', () {
    test('masks bearer tokens and JWTs', () {
      expect(
        scrub('Authorization: Bearer abc.def-ghi'),
        'Authorization: Bearer $redactedValue',
      );
      expect(
        scrub('token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig_nature-1'),
        'token $redactedValue',
      );
    });

    test('masks emails', () {
      expect(scrub('sent to sari.w+1@mail.co.id'), 'sent to «email»');
    });

    test('masks Indonesian phone numbers', () {
      expect(scrub('wa 081234567890'), 'wa «phone»');
      expect(scrub('wa +62 812-3456-7890'), 'wa «phone»');
      expect(scrub('wa 6281234567890.'), 'wa «phone».');
    });

    test('leaves amounts and ids alone', () {
      const text = 'Rp100000 for group 42, request 01HX9';
      expect(scrub(text), text);
    });
  });
}

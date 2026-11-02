import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/core/utils/input_formatters.dart';
import 'package:giliran/core/utils/phone_formatter.dart';
import 'package:giliran/shared/widgets/avatar.dart';
import 'package:giliran/shared/widgets/countdown_text.dart';
import 'package:giliran/shared/widgets/headline_text.dart';

void main() {
  group('Rupiah', () {
    test('formats with dots, no decimals, no space', () {
      expect(Rupiah.format(200000), 'Rp200.000');
      expect(Rupiah.format(2000000), 'Rp2.000.000');
      expect(Rupiah.format(0), 'Rp0');
      expect(Rupiah.format(-150000), '-Rp150.000');
    });

    test('compact form', () {
      expect(Rupiah.compact(2000000), 'Rp2 jt');
      expect(Rupiah.compact(350000), 'Rp350 rb');
      expect(Rupiah.compact(1500000), 'Rp1,5 jt');
      expect(Rupiah.compact(500), 'Rp500');
    });
  });

  group('GiliranColors', () {
    test('toneFor is stable and in range', () {
      const id = '7b0e3c2a-1f4d-4e8a-9c61-2d5b8f0a3e17';
      final a = GiliranColors.toneIndexFor(id);
      expect(GiliranColors.toneIndexFor(id), a);
      expect(a, inInclusiveRange(0, 4));
      expect(GiliranColors.light.toneFor(id), GiliranColors.light.tones[a]);
    });

    test('lerp endpoints match the themes', () {
      final start = GiliranColors.light.lerp(GiliranColors.dark, 0);
      final end = GiliranColors.light.lerp(GiliranColors.dark, 1);
      expect(start.page, GiliranColors.light.page);
      expect(end.page, GiliranColors.dark.page);
      expect(end.paid, GiliranColors.dark.paid);
      expect(end.tones, GiliranColors.dark.tones);
    });

    test('copyWith replaces only the given fields', () {
      final copy = GiliranColors.light.copyWith(hero: AppPalette.telang200);
      expect(copy.hero, AppPalette.telang200);
      expect(copy.page, GiliranColors.light.page);
      expect(copy.pending, GiliranColors.light.pending);
    });

    test('forPayment maps overdue to rejected colors', () {
      const c = GiliranColors.light;
      expect(c.forPayment(PaymentStatus.paid), c.paid);
      expect(c.forPayment(PaymentStatus.pendingReview), c.pending);
      expect(c.forPayment(PaymentStatus.unpaid), c.unpaid);
      expect(c.forPayment(PaymentStatus.unpaid, overdue: true), c.rejected);
      expect(c.forPayment(PaymentStatus.paid, overdue: true), c.paid);
    });

    test('fixed export colors are the same in both themes', () {
      expect(GiliranColors.light.ticketBody, GiliranColors.dark.ticketBody);
      expect(GiliranColors.light.ink, GiliranColors.dark.ink);
      expect(GiliranColors.light.viewerBg, GiliranColors.dark.viewerBg);
    });
  });

  test('PaymentStatus parses API values', () {
    expect(
      PaymentStatus.fromApi('pending_review'),
      PaymentStatus.pendingReview,
    );
    expect(PaymentStatus.fromApi('paid'), PaymentStatus.paid);
  });

  test('SizeClass thresholds', () {
    expect(SizeClass.fromWidth(599), SizeClass.compact);
    expect(SizeClass.fromWidth(600), SizeClass.medium);
    expect(SizeClass.fromWidth(839), SizeClass.medium);
    expect(SizeClass.fromWidth(840), SizeClass.expanded);
    expect(SizeClass.compact.margin, 20);
    expect(SizeClass.expanded.gutter, 24);
  });

  test('AppTextStyles switch to tablet sizes', () {
    expect(const AppTextStyles.phone().headline.fontSize, 26);
    expect(const AppTextStyles.tablet().headline.fontSize, 32);
    expect(const AppTextStyles.phone().amountXl.fontFeatures, isNotEmpty);
    expect(const AppTextStyles.phone().mono.fontFamily, AppFonts.mono);
  });

  group('PhoneFormatter', () {
    test('normalizes 08, 62 and +62 input to E.164', () {
      expect(PhoneFormatter.normalize('0812-3456-7890'), '+6281234567890');
      expect(PhoneFormatter.normalize('6281234567890'), '+6281234567890');
      expect(PhoneFormatter.normalize('+62 812 3456 7890'), '+6281234567890');
      expect(PhoneFormatter.normalize(''), isNull);
    });

    test('displays grouped', () {
      expect(PhoneFormatter.display('+6281234567890'), '+62 812-3456-7890');
      expect(PhoneFormatter.isValid('+6281234567890'), isTrue);
      expect(PhoneFormatter.isValid('+62123'), isFalse);
    });
  });

  group('RupiahInputFormatter', () {
    TextEditingValue format(String text) => const RupiahInputFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: text),
    );

    test('groups digits with dots while typing', () {
      expect(format('200000').text, '200.000');
      expect(format('2.0000').text, '20.000');
      expect(format('0050').text, '50');
      expect(format('').text, '');
      expect(RupiahInputFormatter.parse('2.000.000'), 2000000);
    });

    test('DigitGroupingFormatter groups account numbers by 4', () {
      final v = const DigitGroupingFormatter().formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1234567890'),
      );
      expect(v.text, '1234 5678 90');
    });
  });

  test('HeadlineText.parse marks the bold run', () {
    expect(HeadlineText.parse('Periode 4, **8 orang sudah bayar**.'), [
      ('Periode 4, ', false),
      ('8 orang sudah bayar', true),
      ('.', false),
    ]);
  });

  test('CountdownText formats', () {
    expect(
      CountdownText.formatInline(
        const Duration(days: 2, hours: 4, minutes: 12, seconds: 30),
      ),
      '2 hari 04:12:30',
    );
    expect(CountdownText.formatInline(const Duration(seconds: 42)), '00:00:42');
    expect(
      CountdownText.formatLock(const Duration(minutes: 14, seconds: 52)),
      '14:52',
    );
  });

  test('AppAvatar.initials', () {
    expect(AppAvatar.initials('Rina Wulandari'), 'RW');
    expect(AppAvatar.initials('dedi'), 'D');
    expect(AppAvatar.initials('Mantan anggota'), 'MA');
    expect(AppAvatar.initials('  '), '?');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/reminder/domain/entities/recap.dart';
import 'package:giliran/features/reminder/domain/usecases/build_whatsapp_reminder_usecase.dart';
import 'package:intl/date_symbol_data_local.dart';

final WhatsAppReminderCopy _copy = (
  body: (name, group, period, amount, due) =>
      'Halo $name, iuran $group periode $period sebesar $amount jatuh tempo $due.',
  account: (bank, number, holder) => 'Transfer ke $bank $number a.n. $holder.',
  closing: 'Terima kasih 🙏',
);

final _recap = Recap(
  groupName: 'Arisan RT 05',
  periodNo: 4,
  amount: 200000,
  dueDate: DateTime.utc(2026, 10, 24),
  paymentInfo: const PaymentInfo(bankName: 'BCA', accountNumber: '1234567890', accountHolder: 'Rina'),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  const useCase = BuildWhatsAppReminderUseCase();
  final now = DateTime.utc(2026, 10, 20);

  test('quotes the amount, the period, the due date and the account', () {
    // Act
    final text = useCase((memberName: 'Pak Dedi', recap: _recap, copy: _copy, now: now));

    // Assert
    expect(
      text,
      'Halo Pak Dedi, iuran Arisan RT 05 periode 4 sebesar Rp200.000 jatuh tempo Sab, 24 Okt. '
      'Transfer ke BCA 1234567890 a.n. Rina. Terima kasih 🙏',
    );
  });

  test('leaves the account out when the group has no bank account', () {
    // Act
    final text = useCase((
      memberName: 'Pak Dedi',
      recap: _recap.copyWith(paymentInfo: const PaymentInfo(hasQris: true)),
      copy: _copy,
      now: now,
    ));

    // Assert
    expect(text, isNot(contains('Transfer ke')));
    expect(text, endsWith('jatuh tempo Sab, 24 Okt. Terima kasih 🙏'));
  });

  test('a due date in another year carries the year', () {
    // Act
    final text = useCase((
      memberName: 'Pak Dedi',
      recap: _recap.copyWith(dueDate: DateTime.utc(2026, 12, 31)),
      copy: _copy,
      now: DateTime.utc(2027, 1, 1),
    ));

    // Assert
    expect(text, contains('jatuh tempo 31 Des 2026.'));
  });
}

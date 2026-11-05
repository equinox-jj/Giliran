import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/themes/themes.dart';
import '../../../../core/utils/date_formatter.dart';
import '../entities/recap.dart';

part 'build_whatsapp_reminder_usecase.g.dart';

/// The localized pieces of a WhatsApp reminder, from the ARB files.
typedef WhatsAppReminderCopy = ({
  /// "Halo {name}, iuran {group} periode {period} sebesar {amount} jatuh
  /// tempo {due}."
  String Function(String name, String group, int period, String amount, String due) body,

  /// "Transfer ke {bank} {number} a.n. {holder}."
  String Function(String bank, String number, String holder) account,

  /// "Terima kasih 🙏"
  String closing,
});

typedef WhatsAppReminderParams = ({String memberName, Recap recap, WhatsAppReminderCopy copy, DateTime now});

/// The polite pre-filled WhatsApp reminder an organizer sends to one
/// unpaid member (S41, feature 32): the amount, the period, the due date
/// and the organizer's account. The account line is left out when the
/// group has no bank account yet. Pure, so the page can build it on tap.
class const BuildWhatsAppReminderUseCase() {
  String call(WhatsAppReminderParams params) {
    final recap = params.recap;
    final due = recap.dueDate;
    final info = recap.paymentInfo;
    return [
      params.copy.body(
        params.memberName,
        recap.groupName ?? '',
        recap.periodNo ?? 0,
        Rupiah.format(recap.amount ?? 0),
        due == null ? '-' : AppDate.short(due, now: params.now),
      ),
      if (info != null && info.hasBankAccount)
        params.copy.account(info.bankName ?? '', info.accountNumber ?? '', info.accountHolder ?? ''),
      params.copy.closing,
    ].join(' ');
  }
}

@Riverpod(keepAlive: true)
BuildWhatsAppReminderUseCase buildWhatsAppReminderUseCase(Ref ref) => const BuildWhatsAppReminderUseCase();

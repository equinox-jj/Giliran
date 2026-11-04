import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/l10n/gen/app_localizations_id.dart';
import 'package:giliran/core/utils/enums/payment_method.dart';
import 'package:giliran/features/history/domain/entities/activity_description.dart';
import 'package:giliran/features/history/presentation/shared/activity_copy.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  final l10n = AppLocalizationsId();

  test('every action renders a non-empty sentence and an icon', () {
    for (final kind in ActivityKind.values) {
      // Arrange
      final d = ActivityDescription(kind: kind, actorName: 'Bu Rina', subjectName: 'Pak Dedi');

      // Act
      final sentence = d.sentence(l10n);

      // Assert
      expect(sentence.trim(), isNotEmpty, reason: kind.api);
      expect(sentence, isNot(contains('{')), reason: kind.api);
      expect(d.icon, isNotEmpty, reason: kind.api);
    }
  });

  test('every action renders without names (system actor, former member)', () {
    for (final kind in ActivityKind.values) {
      // Act
      final sentence = ActivityDescription(kind: kind).sentence(l10n);

      // Assert
      expect(sentence.trim(), isNotEmpty, reason: kind.api);
    }
  });

  final cases = <String, ActivityDescription>{
    'Bu Rina membuat grup': const ActivityDescription(kind: ActivityKind.groupCreated, actorName: 'Bu Rina'),
    'Bu Rina mengubah iuran, jumlah slot': const ActivityDescription(
      kind: ActivityKind.groupUpdated,
      actorName: 'Bu Rina',
      changedFields: [ActivityField.amount, ActivityField.totalSlots],
    ),
    'Pak Dedi bergabung (slot 07)': const ActivityDescription(
      kind: ActivityKind.memberJoined,
      subjectName: 'Pak Dedi',
      slotNo: 7,
    ),
    'Periode 4 dibuka · kode komitmen dipublikasikan': const ActivityDescription(
      kind: ActivityKind.periodOpened,
      periodNo: 4,
    ),
    'Bu Rina menolak bukti Pak Dedi: Nominal kurang': const ActivityDescription(
      kind: ActivityKind.paymentRejected,
      actorName: 'Bu Rina',
      subjectName: 'Pak Dedi',
      reason: 'Nominal kurang',
    ),
    'Bu Rina mencatat Pak Dedi bayar tunai': const ActivityDescription(
      kind: ActivityKind.paymentMarkedPaid,
      actorName: 'Bu Rina',
      subjectName: 'Pak Dedi',
      method: PaymentMethod.cash,
    ),
    'Kocokan selesai: slot 07 dapat giliran (8/10 sudah bayar)': const ActivityDescription(
      kind: ActivityKind.drawCompleted,
      actorName: 'Bu Rina',
      slotNo: 7,
      paidCount: 8,
      totalCount: 10,
    ),
    'Bu Rina menyerahkan Rp2.000.000 ke Pak Dedi · arisan selesai': const ActivityDescription(
      kind: ActivityKind.payoutRecorded,
      actorName: 'Bu Rina',
      subjectName: 'Pak Dedi',
      amount: 2000000,
      completedGroup: true,
    ),
    'Mantan anggota keluar dari grup': const ActivityDescription(kind: ActivityKind.memberLeft),
    'Giliran membuat perubahan': const ActivityDescription(kind: ActivityKind.unknown),
  };
  for (final MapEntry(key: expected, value: d) in cases.entries) {
    test('reads "$expected"', () {
      // Act
      final sentence = d.sentence(l10n);

      // Assert
      expect(sentence, expected);
    });
  }

  test('diff lines format money and skip one-sided values', () {
    // Arrange
    const d = ActivityDescription(
      kind: ActivityKind.groupUpdated,
      diffs: [
        ActivityDiff(field: ActivityField.amount, before: 150000, after: 200000),
        ActivityDiff(field: ActivityField.name, after: 'Arisan Baru'),
      ],
    );

    // Act
    final lines = d.diffLines(l10n);

    // Assert
    expect(lines, hasLength(1));
    expect(lines.single.label, 'iuran');
    expect(lines.single.before, 'Rp150.000');
    expect(lines.single.after, 'Rp200.000');
  });
}

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/enums/payment_method.dart';
import '../entities/activity_description.dart';
import '../entities/activity_entry.dart';

part 'describe_activity_usecase.g.dart';

/// Works out what an activity row (Tikar 8.23) says about an entry: the
/// action, the actor and subject names, and the values its sentence and
/// diff line need from `before` / `after`. Unknown actions come back as
/// [ActivityKind.unknown] instead of failing. Pure and synchronous, so it
/// does not go through `UseCase`.
class const DescribeActivityUseCase() {
  /// Group settings in the order the "mengubah {field}" sentence names
  /// them, keyed by their `before` / `after` key.
  static const _settings = {
    'name': ActivityField.name,
    'amount': ActivityField.amount,
    'period_type': ActivityField.periodType,
    'total_slots': ActivityField.totalSlots,
    'draw_method': ActivityField.drawMethod,
    'start_date': ActivityField.startDate,
    'reminder_days_before': ActivityField.reminderDaysBefore,
    'fixed_order': ActivityField.fixedOrder,
  };

  /// Fields whose values are shown on the diff line; the others are only
  /// named.
  static const _shownValues = {
    ActivityField.name,
    ActivityField.amount,
    ActivityField.periodType,
    ActivityField.totalSlots,
    ActivityField.drawMethod,
    ActivityField.startDate,
    ActivityField.reminderDaysBefore,
  };

  ActivityDescription call(ActivityEntry entry) {
    final kind = ActivityKind.fromApi(entry.action);
    final before = entry.before ?? const <String, dynamic>{};
    final after = entry.after ?? const <String, dynamic>{};
    final actor = _text(entry.actor?.name);
    final subject = _text(entry.subject?.displayName);
    final slot = entry.subject?.slotNo;

    return switch (kind) {
      ActivityKind.groupUpdated => _changes(kind, actor, before, after),
      ActivityKind.memberGuestUpdated => ActivityDescription(
        kind: kind,
        actorName: actor,
        subjectName: subject ?? _text(after['name']),
        changedFields: [
          if (after.containsKey('name')) ActivityField.name,
          if (after.containsKey('has_phone')) ActivityField.phone,
        ],
        diffs: [
          if (after.containsKey('name'))
            ActivityDiff(field: ActivityField.name, before: before['name'], after: after['name']),
        ],
      ),
      ActivityKind.groupPaymentInfoUpdated => ActivityDescription(
        kind: kind,
        actorName: actor,
        changedFields: [
          if (after.containsKey('account_number') || after.containsKey('bank_name')) ActivityField.bankAccount,
          if (after.containsKey('qris_merchant_name') || before.containsKey('qris_merchant_name')) ActivityField.qris,
        ],
      ),
      ActivityKind.memberGuestAdded => ActivityDescription(
        kind: kind,
        actorName: actor,
        subjectName: subject ?? _text(after['name']),
        slotNo: slot,
      ),
      ActivityKind.memberGuestClaimed => ActivityDescription(
        kind: kind,
        actorName: actor,
        subjectName: subject ?? _text(before['name']),
        slotNo: slot,
      ),
      ActivityKind.memberLeaveRejected => ActivityDescription(
        kind: kind,
        actorName: actor,
        subjectName: subject,
        reason: _text(after['reason']),
      ),
      ActivityKind.groupStarted => ActivityDescription(
        kind: kind,
        actorName: actor,
        periodNo: _int(after['period_count']),
      ),
      ActivityKind.periodOpened => ActivityDescription(
        kind: kind,
        actorName: actor,
        periodNo: _int(after['period_no']),
      ),
      ActivityKind.paymentRejected => ActivityDescription(
        kind: kind,
        actorName: actor,
        subjectName: subject,
        slotNo: slot,
        reason: _text(after['reject_reason']),
      ),
      ActivityKind.paymentMarkedPaid => ActivityDescription(
        kind: kind,
        actorName: actor,
        subjectName: subject,
        slotNo: slot,
        method: PaymentMethod.fromApi(after['method'] as String?),
      ),
      ActivityKind.drawCompleted => ActivityDescription(
        kind: kind,
        actorName: actor,
        subjectName: subject,
        slotNo: _int(after['winner_slot_no']),
        periodNo: _int(after['period_no']),
        paidCount: _int(after['paid_count']),
        totalCount: _int(after['total_count']),
      ),
      ActivityKind.payoutRecorded => ActivityDescription(
        kind: kind,
        actorName: actor,
        subjectName: subject,
        slotNo: slot,
        periodNo: _int(after['period_no']),
        amount: _int(after['amount']),
        completedGroup: after['group_status'] == 'completed',
      ),
      ActivityKind.reminderSent => ActivityDescription(
        kind: kind,
        actorName: actor,
        sentCount: _int(after['sent_count']),
        skippedCount: _int(after['skipped_count']),
      ),
      _ => ActivityDescription(kind: kind, actorName: actor, subjectName: subject, slotNo: slot),
    };
  }

  static ActivityDescription _changes(
    ActivityKind kind,
    String? actor,
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    final fields = [
      for (final MapEntry(:key, :value) in _settings.entries)
        if (after.containsKey(key) && before[key] != after[key]) value,
    ];
    final keys = {for (final MapEntry(:key, :value) in _settings.entries) value: key};
    return ActivityDescription(
      kind: kind,
      actorName: actor,
      changedFields: fields,
      diffs: [
        for (final f in fields)
          if (_shownValues.contains(f)) ActivityDiff(field: f, before: before[keys[f]], after: after[keys[f]]),
      ],
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _int(Object? value) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v),
    _ => null,
  };
}

@Riverpod(keepAlive: true)
DescribeActivityUseCase describeActivityUseCase(Ref ref) => const DescribeActivityUseCase();

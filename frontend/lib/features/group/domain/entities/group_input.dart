import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/problem_details.dart';
import '../../../../core/utils/enums/draw_method.dart';
import '../../../../core/utils/enums/period_type.dart';

part 'group_input.freezed.dart';

/// What the organizer fills in on Create group (S13–S14).
@freezed
abstract class CreateGroupInput with _$CreateGroupInput {
  const factory({
    required String name,
    required int amount,
    required PeriodType periodType,
    required int totalSlots,

    /// First due date (Jakarta business date).
    required DateTime startDate,
    required DrawMethod drawMethod,
    @Default(GroupRules.defaultReminderDays) int reminderDaysBefore,
  }) = _CreateGroupInput;
}

/// The group settings to change on Edit group (S19); a null field is left
/// as it is. Only [name] and [reminderDaysBefore] may change after start.
@freezed
abstract class UpdateGroupInput with _$UpdateGroupInput {
  const factory({
    String? name,
    int? amount,
    PeriodType? periodType,
    int? totalSlots,
    DateTime? startDate,
    DrawMethod? drawMethod,
    int? reminderDaysBefore,
  }) = _UpdateGroupInput;
}

/// The organizer's bank account on Payment info (S15).
@freezed
abstract class PaymentInfoInput with _$PaymentInfoInput {
  const factory({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) = _PaymentInfoInput;
}

/// Group limits from the API spec, checked on the device before a create or
/// update so obvious mistakes never cost a request. The server checks them
/// again.
abstract final class GroupRules() {
  static const minAmount = 10000;
  static const maxAmount = 100000000;
  static const minSlots = 2;
  static const maxSlots = 50;
  static const minNameLength = 3;
  static const maxNameLength = 60;
  static const minReminderDays = 0;
  static const maxReminderDays = 7;
  static const defaultReminderDays = 2;
  static const maxBankNameLength = 50;
  static const maxAccountHolderLength = 100;
  static final accountNumberPattern = RegExp(r'^[0-9]{6,20}$');

  /// Field errors for the values given, using the API's field codes and an
  /// empty message (the screen supplies the copy). Null values are skipped.
  static List<FieldError> check({
    String? name,
    int? amount,
    int? totalSlots,
    int? reminderDaysBefore,
  }) => [
    if (name != null)
      if (name.trim().length < minNameLength)
        const FieldError(field: 'name', code: 'min_length', message: '')
      else if (name.trim().length > maxNameLength)
        const FieldError(field: 'name', code: 'max_length', message: ''),
    if (amount != null)
      if (amount < minAmount)
        const FieldError(field: 'amount', code: 'minimum_value', message: '')
      else if (amount > maxAmount)
        const FieldError(field: 'amount', code: 'maximum_value', message: ''),
    if (totalSlots != null)
      if (totalSlots < minSlots)
        const FieldError(field: 'total_slots', code: 'minimum_value', message: '')
      else if (totalSlots > maxSlots)
        const FieldError(field: 'total_slots', code: 'maximum_value', message: ''),
    if (reminderDaysBefore != null)
      if (reminderDaysBefore < minReminderDays)
        const FieldError(field: 'reminder_days_before', code: 'minimum_value', message: '')
      else if (reminderDaysBefore > maxReminderDays)
        const FieldError(field: 'reminder_days_before', code: 'maximum_value', message: ''),
  ];
}

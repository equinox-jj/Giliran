import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/error/problem_details.dart';
import '../../../../../core/utils/enums/draw_method.dart';
import '../../../../../core/utils/enums/period_type.dart';
import '../../../domain/entities/group.dart';
import '../../../domain/entities/group_input.dart';
import '../../../domain/usecases/create_group_usecase.dart';
import '../../../domain/usecases/due_date_usecase.dart';

part 'create_group_controller.freezed.dart';
part 'create_group_controller.g.dart';

/// What the organizer has filled in so far on Create group (S13–S14).
@freezed
abstract class const CreateGroupDraft._() with _$CreateGroupDraft {
  const factory({
    /// 1 = basics (S13), 2 = schedule and draw (S14).
    @Default(1) int step,
    @Default('') String name,
    int? amount,
    @Default(PeriodType.monthly) PeriodType periodType,
    @Default(10) int totalSlots,
    DateTime? startDate,
    @Default(DrawMethod.random) DrawMethod drawMethod,
    @Default(GroupRules.defaultReminderDays) int reminderDaysBefore,
    @Default(false) bool submitting,

    /// The last failed submit; field errors show under their fields.
    Failure? failure,
  }) = _CreateGroupDraft;

  /// What one period collects: dues × slots.
  int get potAmount => (amount ?? 0) * totalSlots;
}

/// Holds the Create group draft across both steps and submits it. [build]
/// takes the S24 "Buat arisan baru" prefill.
@riverpod
class CreateGroupController() extends _$CreateGroupController {
  @override
  CreateGroupDraft build({int? prefillAmount, PeriodType? prefillPeriodType, int? prefillTotalSlots}) =>
      CreateGroupDraft(
        amount: prefillAmount,
        periodType: prefillPeriodType ?? PeriodType.monthly,
        totalSlots: prefillTotalSlots ?? 10,
      );

  /// Field errors for step 1 as it stands, from the domain limits.
  List<FieldError> get basicsErrors => GroupRules.check(
    name: state.name,
    amount: state.amount ?? 0,
    totalSlots: state.totalSlots,
  );

  /// The last period's due date, shown under the slots stepper once a start
  /// date is picked. Null before that.
  DateTime? get lastDueDate {
    final start = state.startDate;
    if (start == null) return null;
    return ref.read(dueDateUseCaseProvider)(start: start, periodType: state.periodType, periodNo: state.totalSlots);
  }

  void setName(String value) => state = state.copyWith(name: value, failure: _without('name'));

  void setAmount(int? value) => state = state.copyWith(amount: value, failure: _without('amount'));

  void setPeriodType(PeriodType value) => state = state.copyWith(periodType: value);

  void setTotalSlots(int value) => state = state.copyWith(totalSlots: value, failure: _without('total_slots'));

  void setStartDate(DateTime value) => state = state.copyWith(startDate: value, failure: _without('start_date'));

  void setDrawMethod(DrawMethod value) => state = state.copyWith(drawMethod: value);

  void setReminderDays(int value) => state = state.copyWith(reminderDaysBefore: value);

  /// Moves to step 2 when the basics are valid.
  void next() {
    if (basicsErrors.isEmpty) state = state.copyWith(step: 2);
  }

  /// Back to step 1 ("Ubah" on the review card, or back), keeping values.
  void editBasics() => state = state.copyWith(step: 1);

  /// Sends the draft. Returns the new group, or null when it failed; then a
  /// field error on a step-1 field sends the organizer back there.
  Future<GroupDetail?> submit() async {
    final startDate = state.startDate;
    if (state.submitting || startDate == null) return null;
    state = state.copyWith(submitting: true, failure: null);
    final result = await ref.read(createGroupUseCaseProvider)(
      CreateGroupInput(
        name: state.name,
        amount: state.amount ?? 0,
        periodType: state.periodType,
        totalSlots: state.totalSlots,
        startDate: startDate,
        drawMethod: state.drawMethod,
        reminderDaysBefore: state.reminderDaysBefore,
      ),
    );
    if (!ref.mounted) return result.toNullable();
    switch (result) {
      case Left(:final value):
        final basics =
            value is ValidationFailure &&
            value.fieldErrors.any((e) => const {'name', 'amount', 'total_slots', 'period_type'}.contains(e.field));
        state = state.copyWith(submitting: false, failure: value, step: basics ? 1 : state.step);
        return null;
      case Right(:final value):
        state = state.copyWith(submitting: false);
        return value;
    }
  }

  /// The current failure with [field]'s error removed once it is edited.
  Failure? _without(String field) {
    final failure = state.failure;
    if (failure is! ValidationFailure) return failure;
    final rest = [
      for (final e in failure.fieldErrors)
        if (e.field != field) e,
    ];
    return rest.isEmpty ? null : failure.copyWith(fieldErrors: rest);
  }
}

import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/network/idempotency.dart';
import '../../../../../core/utils/clock.dart';
import '../../../domain/entities/recap.dart';
import '../../../domain/entities/reminder_result.dart';
import '../../../domain/usecases/get_recap_usecase.dart';
import '../../../domain/usecases/resolve_reminder_period_usecase.dart';
import '../../../domain/usecases/send_reminders_usecase.dart';

part 'reminders_controller.freezed.dart';
part 'reminders_controller.g.dart';

/// Reminders and recap (S41): the current period's recap, who is selected
/// for a push reminder, and the rate-limit lock after a `429`.
@freezed
abstract class const RemindersState._() with _$RemindersState {
  const factory({
    required String periodId,
    required Recap recap,

    /// Member ids picked for a push. Guests never get one (no app).
    @Default(<String>{}) Set<String> selected,
    @Default(false) bool busy,

    /// Set from `Retry-After` after `rate_limit_exceeded`; sending waits
    /// until then.
    DateTime? lockedUntil,
  }) = _RemindersState;

  bool get canSend => selected.isNotEmpty && !busy && lockedUntil == null;
}

/// What a send ended with: the result, or the failure to show.
typedef SendOutcome = ({ReminderResult? result, Failure? failure});

/// Loads the recap of a group's current period and sends push reminders.
/// The send keeps its [IdempotencyKey] until it succeeds, so a retry after
/// a timeout is not a second reminder; changing the selection is a new
/// request and gets a new key.
@riverpod
class RemindersController() extends _$RemindersController {
  IdempotencyKey? _sendKey;

  @override
  Future<RemindersState> build(String groupId) async {
    _sendKey = null;
    final periodId = switch (await ref.read(resolveReminderPeriodUseCaseProvider)(groupId)) {
      Left(:final value) => throw value,
      Right(:final value) => value,
    };
    final recap = switch (await ref.read(getRecapUseCaseProvider)((groupId: groupId, periodId: periodId))) {
      Left(:final value) => throw value,
      Right(:final value) => value,
    };
    return RemindersState(
      periodId: periodId,
      recap: recap,
      selected: {
        for (final u in recap.unpaid)
          if (u.member case final m? when !(m.isGuest ?? false) && m.id != null) m.id!,
      },
    );
  }

  void toggle(String memberId, bool value) {
    final current = state.value;
    if (current == null || current.busy) return;
    _sendKey = null;
    final selected = {...current.selected};
    value ? selected.add(memberId) : selected.remove(memberId);
    state = AsyncData(current.copyWith(selected: selected));
  }

  /// The rate-limit wait is over.
  void unlock() {
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(lockedUntil: null));
  }

  /// Pushes a reminder to the selected members. A `429` with `Retry-After`
  /// locks sending until then instead of returning a failure.
  Future<SendOutcome> send() async {
    final current = state.value;
    if (current == null || !current.canSend) return (result: null, failure: null);
    final key = _sendKey ??= IdempotencyKey.generate();
    state = AsyncData(current.copyWith(busy: true));
    final result = await ref.read(sendRemindersUseCaseProvider)((
      groupId: groupId,
      periodId: current.periodId,
      memberIds: current.selected.toList(),
      key: key,
    ));
    if (!ref.mounted) return (result: result.toNullable(), failure: result.getLeft().toNullable());
    switch (result) {
      case Left(value: TooManyRequestsFailure(:final retryAfterDelay?)):
        final until = ref.read(clockProvider)().add(retryAfterDelay);
        state = AsyncData(current.copyWith(busy: false, lockedUntil: until));
        return (result: null, failure: null);
      case Left(:final value):
        state = AsyncData(current.copyWith(busy: false));
        return (result: null, failure: value);
      case Right(:final value):
        _sendKey = null;
        state = AsyncData(current.copyWith(busy: false, selected: const <String>{}));
        return (result: value, failure: null);
    }
  }
}

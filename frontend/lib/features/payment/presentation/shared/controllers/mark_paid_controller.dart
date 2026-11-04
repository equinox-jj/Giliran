import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/network/idempotency.dart';
import '../../../../../core/utils/enums/payment_method.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/mark_paid_usecase.dart';

part 'mark_paid_controller.freezed.dart';
part 'mark_paid_controller.g.dart';

/// The Mark paid sheet (S36): method, note and the "money received" check.
@freezed
abstract class const MarkPaidState._() with _$MarkPaidState {
  const factory({
    @Default(PaymentMethod.cash) PaymentMethod method,
    @Default('') String note,
    @Default(false) bool confirmed,
    @Default(false) bool submitting,
    Failure? failure,
  }) = _MarkPaidState;

  bool get noteTooLong => note.trim().length > MarkPaidUseCase.maxNoteLength;

  bool get canSubmit => confirmed && !submitting && !noteTooLong;
}

/// Records a payment as paid (S36). The mark's [IdempotencyKey] is made on
/// the first submit and reused on retries; offline the mark is queued.
@riverpod
class MarkPaidController() extends _$MarkPaidController {
  IdempotencyKey? _key;

  @override
  MarkPaidState build(String groupId, String paymentId) => const MarkPaidState();

  void setMethod(PaymentMethod method) {
    _key = null;
    state = state.copyWith(method: method);
  }

  void setNote(String note) {
    _key = null;
    state = state.copyWith(note: note);
  }

  void setConfirmed(bool value) => state = state.copyWith(confirmed: value);

  /// Sends the mark. Returns the saved payment (`pendingSync` when queued
  /// offline), or null on failure.
  Future<Payment?> submit() async {
    if (!state.canSubmit) return null;
    final key = _key ??= IdempotencyKey.generate();
    state = state.copyWith(submitting: true, failure: null);
    final result = await ref.read(markPaidUseCaseProvider)((
      groupId: groupId,
      paymentId: paymentId,
      method: state.method,
      note: state.note,
      key: key,
    ));
    if (!ref.mounted) return result.toNullable();
    return result.match(
      (failure) {
        state = state.copyWith(submitting: false, failure: failure);
        return null;
      },
      (payment) {
        _key = null;
        state = state.copyWith(submitting: false);
        return payment;
      },
    );
  }
}

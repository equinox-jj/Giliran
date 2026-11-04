import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/network/idempotency.dart';
import '../../../../../core/services/image_picker_service.dart';
import '../../../../../core/utils/enums/photo_source.dart';
import '../../../domain/entities/payout.dart';
import '../../../domain/usecases/confirm_payout_usecase.dart';
import '../../../domain/usecases/get_payout_usecase.dart';
import '../../../domain/usecases/record_payout_usecase.dart';
import '../../../domain/usecases/watch_payout_usecase.dart';

part 'payout_controller.freezed.dart';
part 'payout_controller.g.dart';

/// The payout screen (S40): the cached payout, and the organizer's record
/// form (optional proof, note, "Uang sudah saya serahkan").
@freezed
abstract class const PayoutState._() with _$PayoutState {
  const factory({
    Payout? payout,
    String? proofPath,
    @Default('') String note,
    @Default(false) bool handedOver,
    @Default(false) bool busy,
    Failure? failure,

    /// The user blocked camera or photo access.
    @Default(false) bool denied,
  }) = _PayoutState;

  bool get canRecord => handedOver && !busy;
}

/// Watches a period's payout, refreshes it on open, and records or
/// confirms it. Each intent keeps its [IdempotencyKey] until it succeeds;
/// changing the proof or the note is a new request and gets a new key.
@riverpod
class PayoutController() extends _$PayoutController {
  IdempotencyKey? _recordKey;
  IdempotencyKey? _confirmKey;
  StreamSubscription<void>? _sub;

  @override
  PayoutState build(String groupId, String periodId) {
    _sub = ref.watch(watchPayoutUseCaseProvider)(periodId).listen((result) {
      if (result case Right(:final value?) when ref.mounted) state = state.copyWith(payout: value);
    });
    ref.onDispose(() => _sub?.cancel());
    unawaited(Future.microtask(refresh));
    return const PayoutState();
  }

  /// Fetches the payout into the cache. Not recorded yet answers 404, which
  /// is not an error here.
  Future<void> refresh() async {
    final result = await ref.read(getPayoutUseCaseProvider)((groupId: groupId, periodId: periodId));
    if (!ref.mounted) return;
    if (result case Right(:final value)) state = state.copyWith(payout: value);
  }

  Future<void> pick(PhotoSource source) async {
    final picked = await ref.read(imagePickerServiceProvider).pick(source);
    if (!ref.mounted) return;
    if (picked.path == null) {
      state = state.copyWith(denied: picked.denied);
      return;
    }
    _recordKey = null;
    state = state.copyWith(proofPath: picked.path, failure: null, denied: false);
  }

  void removeProof() {
    _recordKey = null;
    state = state.copyWith(proofPath: null, failure: null);
  }

  void setNote(String value) {
    if (value.trim() == state.note.trim()) return;
    _recordKey = null;
    state = state.copyWith(note: value);
  }

  void setHandedOver(bool value) => state = state.copyWith(handedOver: value);

  /// Records the payout. Returns the failure, or null when it was recorded.
  Future<Failure?> record() async {
    if (!state.canRecord) return null;
    final key = _recordKey ??= IdempotencyKey.generate();
    final note = state.note.trim();
    state = state.copyWith(busy: true, failure: null);
    final result = await ref.read(recordPayoutUseCaseProvider)((
      groupId: groupId,
      periodId: periodId,
      proofPath: state.proofPath,
      note: note.isEmpty ? null : note,
      key: key,
    ));
    return _settle(result, onSuccess: () => _recordKey = null);
  }

  /// The winner confirms the pot arrived.
  Future<Failure?> confirm() async {
    if (state.busy) return null;
    final key = _confirmKey ??= IdempotencyKey.generate();
    state = state.copyWith(busy: true, failure: null);
    final result = await ref.read(confirmPayoutUseCaseProvider)((groupId: groupId, periodId: periodId, key: key));
    return _settle(result, onSuccess: () => _confirmKey = null);
  }

  Failure? _settle(Either<Failure, Payout> result, {required void Function() onSuccess}) {
    if (!ref.mounted) return result.getLeft().toNullable();
    switch (result) {
      case Left(:final value):
        state = state.copyWith(busy: false, failure: value);
        return value;
      case Right(:final value):
        onSuccess();
        state = state.copyWith(busy: false, payout: value);
        return null;
    }
  }
}

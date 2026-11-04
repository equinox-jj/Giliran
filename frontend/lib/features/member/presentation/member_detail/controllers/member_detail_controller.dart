import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/entities/claim_link.dart';
import '../../../domain/entities/member.dart';
import '../../../domain/entities/obligation.dart';
import '../../../domain/usecases/create_claim_link_usecase.dart';
import '../../../domain/usecases/get_member_usecase.dart';
import '../../../domain/usecases/get_obligations_usecase.dart';
import '../../../domain/usecases/remove_member_usecase.dart';
import '../../../domain/usecases/watch_member_usecase.dart';

part 'member_detail_controller.freezed.dart';
part 'member_detail_controller.g.dart';

/// Member detail (S26): the cached member and what they still owe after
/// winning.
@freezed
abstract class MemberDetailState with _$MemberDetailState {
  const factory({
    Member? member,
    Obligation? obligation,
    @Default(false) bool loaded,

    /// The server says the member is gone.
    @Default(false) bool notFound,
    @Default(false) bool busy,
  }) = _MemberDetailState;
}

/// Watches one cached member, fetches it and its obligation on open, and
/// runs the organizer actions (claim link, removal).
@riverpod
class MemberDetailController() extends _$MemberDetailController {
  Member? _member;
  Obligation? _obligation;
  var _loaded = false;
  var _notFound = false;
  var _busy = false;

  @override
  Stream<MemberDetailState> build(String groupId, String memberId) {
    unawaited(Future.microtask(refresh));
    return ref.watch(watchMemberUseCaseProvider)(memberId).map((result) {
      switch (result) {
        case Left(:final value):
          throw value;
        case Right(:final value):
          _member = value;
          if (value != null) _loaded = true;
          return _compose();
      }
    });
  }

  /// Fetches the member and the obligations. Returns the failure, if any.
  Future<Failure?> refresh() async {
    final (member, obligations) = await (
      ref.read(getMemberUseCaseProvider)((groupId: groupId, memberId: memberId)),
      ref.read(getObligationsUseCaseProvider)(groupId),
    ).wait;
    if (!ref.mounted) return member.getLeft().toNullable();
    _loaded = true;
    _notFound = member.getLeft().toNullable() is NotFoundFailure;
    _obligation = obligations.getOrElse((_) => const []).where((o) => o.memberId == memberId).firstOrNull;
    _emit();
    return member.getLeft().toNullable();
  }

  /// A fresh claim link for this guest. Returns it, or the failure.
  Future<Either<Failure, ClaimLink>> createClaimLink() =>
      _busyWhile(() => ref.read(createClaimLinkUseCaseProvider)((groupId: groupId, memberId: memberId)));

  /// Removes the member. Returns the failure, if any.
  Future<Failure?> remove() async {
    final result = await _busyWhile(
      () => ref.read(removeMemberUseCaseProvider)((groupId: groupId, memberId: memberId)),
    );
    return result.getLeft().toNullable();
  }

  Future<T> _busyWhile<T>(Future<T> Function() body) async {
    _busy = true;
    _emit();
    try {
      return await body();
    } finally {
      _busy = false;
      if (ref.mounted) _emit();
    }
  }

  void _emit() {
    if (state.hasValue) state = AsyncData(_compose());
  }

  MemberDetailState _compose() => MemberDetailState(
    member: _member,
    obligation: _obligation,
    loaded: _loaded,
    notFound: _notFound,
    busy: _busy,
  );
}

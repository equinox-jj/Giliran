import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/entities/member.dart';
import '../../../domain/usecases/refresh_members_usecase.dart';
import '../../../domain/usecases/watch_members_usecase.dart';

part 'members_controller.g.dart';

/// A group's cached members by slot number, refreshed from the API on open
/// and on [refresh]. Shared by Invite, the Anggota tab, Fixed order, Start
/// and the transfer offer.
@riverpod
class MembersController() extends _$MembersController {
  @override
  Stream<List<Member>> build(String groupId) {
    unawaited(Future.microtask(refresh));
    return ref
        .watch(watchMembersUseCaseProvider)(groupId)
        .map(
          (result) => switch (result) {
            Left(:final value) => throw value,
            Right(:final value) => value,
          },
        );
  }

  /// Fetches the members into the cache. Returns the failure, if any.
  Future<Failure?> refresh() async {
    final result = await ref.read(refreshMembersUseCaseProvider)(groupId);
    return result.getLeft().toNullable();
  }
}

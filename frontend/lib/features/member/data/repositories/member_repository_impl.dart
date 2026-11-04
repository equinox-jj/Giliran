import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/enums/group_list_filter.dart';
import '../../../../core/utils/logger/app_logger.dart';
import '../../../group/data/datasource/group_local_data_source.dart';
import '../../../group/data/datasource/group_local_data_source_impl.dart';
import '../../../group/data/datasource/group_remote_data_source.dart';
import '../../../group/data/datasource/group_remote_data_source_impl.dart';
import '../../../group/data/mappers/group_mapper.dart';
import '../../../group/domain/entities/group.dart';
import '../../domain/entities/claim_link.dart';
import '../../domain/entities/invite_preview.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/member_input.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/entities/ownership_transfer.dart';
import '../../domain/repositories/member_repository.dart';
import '../datasource/member_local_data_source.dart';
import '../datasource/member_local_data_source_impl.dart';
import '../datasource/member_remote_data_source.dart';
import '../datasource/member_remote_data_source_impl.dart';
import '../mappers/member_mapper.dart';

part 'member_repository_impl.g.dart';

class MemberRepositoryImpl(
  final MemberRemoteDataSource _remote,
  final MemberLocalDataSource _local,
  final GroupRemoteDataSource _groupRemote,
  final GroupLocalDataSource _groupLocal,
) with BaseRepository implements MemberRepository {
  @override
  Stream<Either<Failure, List<Member>>> watchMembers(String groupId) => safeStream(
    _local.watchMembers(groupId).map((rows) => [for (final row in rows) row.toEntity()]),
  );

  @override
  Future<Either<Failure, Unit>> refreshMembers(String groupId) => safeCall(() async {
    await _saveMembers(groupId);
    return unit;
  });

  @override
  Stream<Either<Failure, Member?>> watchMember(String memberId) =>
      safeStream(_local.watchMember(memberId).map((row) => row?.toEntity()));

  @override
  Future<Either<Failure, Member>> getMember(String groupId, String memberId) => safeCall(() async {
    try {
      final model = await _remote.getMember(groupId, memberId);
      await _local.upsertMembers([model.toCompanion(groupId)]);
      return model.toEntity(groupId: groupId);
    } on NotFoundException {
      await _local.deleteMember(memberId);
      rethrow;
    }
  });

  @override
  Future<Either<Failure, InvitePreview>> getInvitePreview(String code) =>
      safeCall(() async => (await _remote.getInvitePreview(code)).toEntity());

  @override
  Future<Either<Failure, Member>> joinGroup(String code) => safeCall(() async {
    final (:member, :groupId) = await _remote.joinGroup(code);
    if (groupId != null) {
      // The group row must be cached before its member (foreign key).
      await _quietly(() async {
        await _saveGroup(groupId);
        await _local.upsertMembers([member.toCompanion(groupId)]);
      });
    }
    return member.toEntity(groupId: groupId);
  });

  @override
  Future<Either<Failure, Invite>> resetInviteCode(String groupId) => safeCall(() async {
    final invite = await _remote.resetInviteCode(groupId);
    await _quietly(() => _saveGroup(groupId));
    return invite.toEntity();
  });

  @override
  Future<Either<Failure, Member>> addGuest(String groupId, GuestInput input) => safeCall(() async {
    final member = await _remote.addGuest(groupId, input.toRequest());
    await _local.upsertMembers([member.toCompanion(groupId)]);
    await _quietly(() => _saveGroup(groupId));
    return member.toEntity(groupId: groupId);
  });

  @override
  Future<Either<Failure, Member>> updateGuest(String groupId, String memberId, UpdateGuestInput input) =>
      safeCall(() async {
        final member = await _remote.updateGuest(groupId, memberId, input.toBody());
        await _local.upsertMembers([member.toCompanion(groupId)]);
        return member.toEntity(groupId: groupId);
      });

  @override
  Future<Either<Failure, Unit>> removeMember(String groupId, String memberId) => safeCall(() async {
    await _remote.removeMember(groupId, memberId);
    await _local.deleteMember(memberId);
    await _quietly(() => _saveGroup(groupId));
    return unit;
  });

  @override
  Future<Either<Failure, ClaimLink>> createClaimLink(String groupId, String memberId) =>
      safeCall(() async => (await _remote.createClaimLink(groupId, memberId)).toEntity());

  @override
  Future<Either<Failure, String?>> claimSlot(String token) => safeCall(() async {
    // The claimed member doesn't name its group, so the group is the one
    // that appears in the list after the claim.
    final before = {for (final g in await _groupRemote.listMyGroups(GroupListFilter.all.apiValue)) g.id};
    await _remote.claimSlot(token);
    String? groupId;
    await _quietly(() async {
      final after = await _groupRemote.listMyGroups(GroupListFilter.all.apiValue);
      await _groupLocal.replaceGroups(
        [for (final g in after) g.toCompanion()],
        GroupListFilter.all.statusValues,
      );
      groupId = after.where((g) => !before.contains(g.id)).firstOrNull?.id;
    });
    return groupId;
  });

  @override
  Future<Either<Failure, List<LeaveRequest>>> getLeaveRequests(String groupId, {String? status}) => safeCall(() async {
    final requests = await _remote.listLeaveRequests(groupId, status: status);
    return [for (final r in requests) r.toEntity()];
  });

  @override
  Future<Either<Failure, LeaveRequest>> requestLeave(String groupId, {String? reason}) =>
      safeCall(() async => (await _remote.requestLeave(groupId, reason: reason)).toEntity());

  @override
  Future<Either<Failure, LeaveRequest>> approveLeave(String groupId, String requestId) => safeCall(() async {
    final request = await _remote.approveLeave(groupId, requestId);
    await _quietly(() async {
      await _saveMembers(groupId);
      await _saveGroup(groupId);
    });
    return request.toEntity();
  });

  @override
  Future<Either<Failure, LeaveRequest>> rejectLeave(String groupId, String requestId, {String? reason}) =>
      safeCall(() async => (await _remote.rejectLeave(groupId, requestId, reason: reason)).toEntity());

  @override
  Future<Either<Failure, OwnershipTransfer>> offerTransfer(String groupId, String toMemberId) =>
      safeCall(() async => (await _remote.offerTransfer(groupId, toMemberId)).toEntity());

  @override
  Future<Either<Failure, OwnershipTransfer>> acceptTransfer(String groupId, String transferId) => safeCall(() async {
    final transfer = await _remote.acceptTransfer(groupId, transferId);
    // Roles changed on both sides.
    await _quietly(() async {
      await _saveGroup(groupId);
      await _saveMembers(groupId);
    });
    return transfer.toEntity();
  });

  @override
  Future<Either<Failure, OwnershipTransfer>> declineTransfer(String groupId, String transferId) =>
      safeCall(() async => (await _remote.declineTransfer(groupId, transferId)).toEntity());

  @override
  Future<Either<Failure, List<Member>>> saveFixedOrder(String groupId, List<FixedOrderEntry> order) =>
      safeCall(() async {
        final members = await _remote.saveFixedOrder(groupId, order.toRequest());
        await _local.replaceMembers(groupId, [for (final m in members) m.toCompanion(groupId)]);
        return [for (final m in members) m.toEntity(groupId: groupId)];
      });

  @override
  Future<Either<Failure, GroupDetail>> startGroup(String groupId) => safeCall(() async {
    final group = await _remote.startGroup(groupId);
    await _groupLocal.upsertGroup(group.toCompanion());
    return group.toEntity();
  });

  @override
  Future<Either<Failure, List<Obligation>>> getObligations(String groupId) => safeCall(() async {
    final obligations = await _remote.listObligations(groupId);
    return [for (final o in obligations) o.toEntity()];
  });

  Future<void> _saveMembers(String groupId) async {
    final members = await _remote.listMembers(groupId);
    await _local.replaceMembers(groupId, [for (final m in members) m.toCompanion(groupId)]);
  }

  Future<void> _saveGroup(String groupId) async =>
      _groupLocal.upsertGroup((await _groupRemote.getGroup(groupId)).toCompanion());

  /// Runs a cache follow-up after a write that already succeeded on the
  /// server. Its failure must not report the write as failed; the next
  /// screen refresh catches up.
  Future<void> _quietly(Future<void> Function() body) async {
    try {
      await body();
    } on AppException catch (e, st) {
      AppLogger.w('Cache follow-up failed', tag: 'member', error: e, stackTrace: st);
    }
  }
}

@Riverpod(keepAlive: true)
MemberRepository memberRepository(Ref ref) => MemberRepositoryImpl(
  ref.watch(memberRemoteDataSourceProvider),
  ref.watch(memberLocalDataSourceProvider),
  ref.watch(groupRemoteDataSourceProvider),
  ref.watch(groupLocalDataSourceProvider),
);

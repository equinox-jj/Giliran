import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/enums/group_list_filter.dart';
import '../entities/group.dart';
import '../entities/group_input.dart';
import '../entities/group_summary.dart';

/// Groups the signed-in user belongs to. Screens watch the on-device cache
/// and ask for a refresh, which writes the server's answer into the cache
/// (server wins); writes go to the server and then update the cache.
abstract interface class GroupRepository() {
  /// Cached groups for [filter], re-emitted whenever the cache changes.
  Stream<Either<Failure, List<GroupSummary>>> watchMyGroups(GroupListFilter filter);

  /// `GET /me/groups?status=` into the cache.
  Future<Either<Failure, Unit>> refreshMyGroups(GroupListFilter filter);

  /// One cached group; `null` until it has been fetched or after it is gone.
  Stream<Either<Failure, GroupDetail?>> watchGroup(String id);

  /// `GET /groups/{id}` into the cache. Returns the fresh group, the only
  /// place the signed QRIS URL appears.
  Future<Either<Failure, GroupDetail>> refreshGroup(String id);

  /// `POST /groups`.
  Future<Either<Failure, GroupDetail>> createGroup(CreateGroupInput input);

  /// `PATCH /groups/{id}` with only the fields set in [input].
  Future<Either<Failure, GroupDetail>> updateGroup(String id, UpdateGroupInput input);

  /// `POST /groups/{id}/close`.
  Future<Either<Failure, GroupDetail>> closeGroup(String id);

  /// `PUT /groups/{id}/payment-info`.
  Future<Either<Failure, GroupDetail>> updatePaymentInfo(String id, PaymentInfoInput input);

  /// `PUT /groups/{id}/payment-info/qris` with the image at [path].
  Future<Either<Failure, GroupDetail>> uploadQris(String id, String path);

  /// `DELETE /groups/{id}/payment-info/qris`.
  Future<Either<Failure, Unit>> deleteQris(String id);
}

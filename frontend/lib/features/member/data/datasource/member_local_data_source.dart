import '../../../../core/database/app_database.dart';

/// The cached members in the on-device database.
abstract interface class MemberLocalDataSource() {
  /// A group's cached members by slot number.
  Stream<List<MemberRow>> watchMembers(String groupId);

  Stream<MemberRow?> watchMember(String memberId);

  /// Writes a full list fetch: the group's cached members become [rows].
  Future<void> replaceMembers(String groupId, List<MembersCompanion> rows);

  Future<void> upsertMembers(List<MembersCompanion> rows);

  Future<void> deleteMember(String memberId);
}

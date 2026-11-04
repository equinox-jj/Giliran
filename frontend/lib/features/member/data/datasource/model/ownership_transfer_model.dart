// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../group/data/datasource/model/group_model.dart';
import 'member_model.dart';

part 'ownership_transfer_model.freezed.dart';
part 'ownership_transfer_model.g.dart';

/// `OwnershipTransfer` from the ownership-transfer endpoints.
@freezed
abstract class OwnershipTransferModel with _$OwnershipTransferModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'from_user') UserSummaryModel? fromUser,
    @JsonKey(name: 'to_member') MemberRefModel? toMember,
    @JsonKey(name: 'status') String? status,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'responded_at') DateTime? respondedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _OwnershipTransferModel;

  factory fromJson(Map<String, dynamic> json) => _$OwnershipTransferModelFromJson(json);
}

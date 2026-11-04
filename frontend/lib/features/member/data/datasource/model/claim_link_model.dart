// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'claim_link_model.freezed.dart';
part 'claim_link_model.g.dart';

/// `ClaimLink` from `POST /members/{id}/claim-link`.
@freezed
abstract class ClaimLinkModel with _$ClaimLinkModel {
  const factory({
    @JsonKey(name: 'claim_url') String? claimUrl,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
  }) = _ClaimLinkModel;

  factory fromJson(Map<String, dynamic> json) => _$ClaimLinkModelFromJson(json);
}

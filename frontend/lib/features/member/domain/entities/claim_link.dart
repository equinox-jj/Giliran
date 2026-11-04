import 'package:freezed_annotation/freezed_annotation.dart';

part 'claim_link.freezed.dart';

/// A 7-day link a guest opens to take over their slot (S28).
@freezed
abstract class ClaimLink with _$ClaimLink {
  const factory({String? url, DateTime? expiresAt}) = _ClaimLink;
}

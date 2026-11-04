import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/problem_details.dart';

part 'member_input.freezed.dart';

/// A guest to add on S27.
@freezed
abstract class GuestInput with _$GuestInput {
  const factory({required String name, String? phone}) = _GuestInput;
}

/// A guest edit on S27. A null [name] or [phone] is left as it is;
/// [clearPhone] removes the phone.
@freezed
abstract class UpdateGuestInput with _$UpdateGuestInput {
  const factory({String? name, String? phone, @Default(false) bool clearPhone}) = _UpdateGuestInput;
}

/// One slot's place in a fixed winning order (S17), 1 wins first.
@freezed
abstract class FixedOrderEntry with _$FixedOrderEntry {
  const factory({required String slotId, required int position}) = _FixedOrderEntry;
}

/// Member limits from the API spec, checked on the device before a request.
/// The server checks them again.
abstract final class MemberRules() {
  static const minGuestNameLength = 2;
  static const maxGuestNameLength = 50;
  static const maxReasonLength = 500;
  static const minRejectReasonLength = 3;

  /// Field errors for a guest name, using the API's field codes and an
  /// empty message (the screen supplies the copy).
  static List<FieldError> checkGuestName(String name) => [
    if (name.trim().length < minGuestNameLength)
      const FieldError(field: 'name', code: 'min_length', message: '')
    else if (name.trim().length > maxGuestNameLength)
      const FieldError(field: 'name', code: 'max_length', message: ''),
  ];

  /// Field errors for an optional reason; [minLength] applies only when one
  /// is given.
  static List<FieldError> checkReason(String? reason, {int minLength = 0}) {
    final text = reason?.trim() ?? '';
    return [
      if (text.length > maxReasonLength)
        const FieldError(field: 'reason', code: 'max_length', message: '')
      else if (text.isNotEmpty && text.length < minLength)
        const FieldError(field: 'reason', code: 'min_length', message: ''),
    ];
  }
}

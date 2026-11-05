import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/reminder_skip_reason.dart';
import '../../../member/domain/entities/member.dart';

part 'reminder_result.freezed.dart';

/// A member the push reminder skipped; [reason] is null for a reason this
/// app version does not know.
@freezed
abstract class SkippedReminder with _$SkippedReminder {
  const factory({MemberRef? member, ReminderSkipReason? reason, String? whatsappPhone}) = _SkippedReminder;
}

/// The answer to "Kirim notifikasi" (S41): pushes sent, and who was skipped
/// so the organizer can use WhatsApp instead.
@freezed
abstract class ReminderResult with _$ReminderResult {
  const factory({@Default(0) int sentCount, @Default(<SkippedReminder>[]) List<SkippedReminder> skipped}) =
      _ReminderResult;
}

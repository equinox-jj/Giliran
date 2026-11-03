import 'package:freezed_annotation/freezed_annotation.dart';

part 'agenda_day.freezed.dart';

/// An event on the Home agenda strip, in display priority order: a due date
/// outranks a draw, which outranks a payout.
enum AgendaEventKind() {
  due,
  draw,
  payout,
}

/// One group's event on an agenda day.
@freezed
abstract class AgendaEvent with _$AgendaEvent {
  const factory({
    required AgendaEventKind kind,
    required String groupId,
    required String groupName,
  }) = _AgendaEvent;
}

/// One day of the 7-day agenda strip (Tikar §9.9).
@freezed
abstract class const AgendaDay._() with _$AgendaDay {
  const factory({
    /// Jakarta business date at UTC midnight.
    required DateTime date,
    required bool isToday,

    /// Every event that day, highest priority first.
    @Default(<AgendaEvent>[]) List<AgendaEvent> events,
  }) = _AgendaDay;

  /// The event the day's token shows, or null for an empty day.
  AgendaEventKind? get topKind => events.isEmpty ? null : events.first.kind;
}

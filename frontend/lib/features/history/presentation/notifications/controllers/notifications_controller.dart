import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/entities/notification_entry.dart';
import '../../../domain/usecases/mark_notifications_read_usecase.dart';
import '../../../domain/usecases/resolve_notification_target_usecase.dart';
import '../../../domain/usecases/watch_notifications_usecase.dart';

part 'notifications_controller.freezed.dart';
part 'notifications_controller.g.dart';

/// The Aktivitas tab (S12): the stored notifications under the chosen
/// chip.
@freezed
abstract class NotificationsState with _$NotificationsState {
  const factory({
    @Default(NotificationFilter.all) NotificationFilter filter,

    /// Newest first, already filtered.
    @Default(<NotificationEntry>[]) List<NotificationEntry> entries,

    /// Any unread notification exists, whatever the filter shows.
    @Default(false) bool hasUnread,
    @Default(false) bool loaded,
  }) = _NotificationsState;
}

/// Watches the device's notifications under a filter chip, marks them read
/// (one on swipe or tap, all from the app bar) and resolves where a tap
/// goes.
@riverpod
class NotificationsController() extends _$NotificationsController {
  StreamSubscription<void>? _filteredSub;
  StreamSubscription<void>? _unreadSub;

  @override
  NotificationsState build() {
    ref.onDispose(_cancel);
    _watch(NotificationFilter.all);
    _unreadSub = ref.read(watchNotificationsUseCaseProvider)(NotificationFilter.unread).listen((result) {
      if (result case Right(:final value)) state = state.copyWith(hasUnread: value.isNotEmpty);
    });
    return const NotificationsState();
  }

  void setFilter(NotificationFilter filter) {
    if (filter == state.filter) return;
    state = state.copyWith(filter: filter);
    _watch(filter);
  }

  Future<void> markRead(String id) async => ref.read(markNotificationsReadUseCaseProvider)(id);

  Future<void> markAllRead() async => ref.read(markNotificationsReadUseCaseProvider)(null);

  /// Marks [entry] read and returns where its tap goes.
  Future<NotificationTarget> open(NotificationEntry entry) async {
    if (!entry.read) await markRead(entry.id);
    return ref.read(resolveNotificationTargetUseCaseProvider)((
      kind: entry.kind,
      groupId: entry.groupId,
      periodId: entry.periodId,
      paymentId: entry.paymentId,
    ));
  }

  void _watch(NotificationFilter filter) {
    unawaited(_filteredSub?.cancel());
    _filteredSub = ref.read(watchNotificationsUseCaseProvider)(filter).listen((result) {
      if (result case Right(:final value) when filter == state.filter) {
        state = state.copyWith(entries: value, loaded: true);
      }
    });
  }

  void _cancel() {
    unawaited(_filteredSub?.cancel());
    unawaited(_unreadSub?.cancel());
  }
}

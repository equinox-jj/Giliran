import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/database/app_database.dart';
import '../core/services/push_service.dart';
import '../core/utils/logger/app_logger.dart';
import '../features/auth/domain/entities/auth_status.dart';
import '../features/auth/presentation/shared/controllers/auth_session_controller.dart';
import '../features/group/presentation/group_detail/widgets/detail_tabs.dart';
import '../features/history/data/mappers/notification_mapper.dart';
import '../features/history/domain/entities/notification_entry.dart';
import '../features/history/domain/usecases/mark_notifications_read_usecase.dart';
import '../features/history/domain/usecases/register_push_token_usecase.dart';
import '../features/history/domain/usecases/resolve_notification_target_usecase.dart';
import '../features/history/domain/usecases/store_notification_usecase.dart';
import '../firebase_options.dart';
import 'router.dart';
import 'routes.dart';

part 'push_controller.g.dart';

const _tag = 'push';

/// The in-app location of a notification target (route map §10.2).
String notificationLocation(NotificationTarget target) => switch (target) {
  InboxTarget() => const ActivityRoute().location,
  GroupTarget(:final groupId, :final tab) => GroupDetailRoute(
    gid: groupId,
    tab: switch (tab) {
      GroupTargetTab.payments => DetailTab.payments.query,
      GroupTargetTab.members => DetailTab.members.query,
      null => null,
    },
  ).location,
  ProofReviewTarget(:final groupId, :final paymentId) => ProofReviewRoute(gid: groupId, payId: paymentId).location,
  DrawResultTarget(:final groupId, :final periodId) => DrawResultRoute(gid: groupId, pid: periodId).location,
  PayoutTarget(:final groupId, :final periodId) => PayoutRoute(gid: groupId, pid: periodId).location,
};

/// Runs push for the app's lifetime: wires [PushService], keeps every
/// received push for the Aktivitas tab, saves the FCM token on the
/// session once signed in and on every refresh, and opens a tapped
/// notification's target, waiting until the app is unlocked.
@Riverpod(keepAlive: true)
class PushController() extends _$PushController {
  final _subs = <StreamSubscription<void>>[];
  var _hasSession = false;
  var _unlocked = false;
  var _registered = false;
  NotificationTarget? _pending;

  @override
  void build() {
    ref.onDispose(() {
      for (final s in _subs) {
        unawaited(s.cancel());
      }
    });

    ref.listen(
      authSessionControllerProvider,
      (_, next) => _onAuth(next.value),
      fireImmediately: true,
    );

    unawaited(_start());
  }

  Future<void> _start() async {
    final push = ref.read(pushServiceProvider);

    try {
      await push.init();
    } on Exception catch (e, st) {
      AppLogger.w(
        'Push setup failed',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      return;
    }

    if (!ref.mounted) return;

    _subs
      ..add(push.received.listen((m) => unawaited(ref.read(storeNotificationUseCaseProvider)(m))))
      ..add(push.opened.listen((m) => unawaited(_open(m))))
      ..add(
        push.tokenRefreshes.listen((token) {
          if (_hasSession) unawaited(_register(token));
        }),
      );
    if (_hasSession && !_registered) unawaited(_registerCurrent());

    final initial = await push.initialMessage();
    if (initial != null && ref.mounted) await _open(initial);
  }

  void _onAuth(AuthStatus? status) {
    _hasSession = switch (status) {
      AuthLocked() || AuthUnlocked() || AuthNeedsName() || AuthNeedsPin() => true,
      _ => false,
    };
    _unlocked = status is AuthUnlocked;

    if (!_hasSession) {
      // The next account on this device registers its own session.
      _registered = false;
      _pending = null;
      return;
    }
    if (!_registered) unawaited(_registerCurrent());

    _flush();
  }

  /// Saves the current token once per session. The flag is set before the
  /// token read, so the sign-in and startup paths can't both send it.
  Future<void> _registerCurrent() async {
    _registered = true;

    final token = await ref.read(pushServiceProvider).token();
    if (!ref.mounted) return;
    if (token == null) {
      _registered = false;
      return;
    }

    await _register(token);
  }

  Future<void> _register(String token) async {
    _registered = true;
    final result = await ref.read(registerPushTokenUseCaseProvider)(token);
    if (result.isLeft()) {
      // Retried on the next sign-in or token refresh.
      _registered = false;

      AppLogger.w('Push token not saved', tag: _tag, error: result.getLeft().toNullable());
    }
  }

  Future<void> _open(PushMessage message) async {
    final stored = await ref.read(storeNotificationUseCaseProvider)(message);
    if (!ref.mounted) return;
    if (stored case Right(value: final id?)) await ref.read(markNotificationsReadUseCaseProvider)(id);
    if (!ref.mounted) return;

    final data = message.data;

    _pending = ref.read(resolveNotificationTargetUseCaseProvider)((
      kind: PushKind.fromApi(data['type']),
      groupId: data['group_id'],
      periodId: data['period_id'],
      paymentId: data['payment_id'],
    ));

    _flush();
  }

  void _flush() {
    final target = _pending;
    if (target == null || !_unlocked) return;

    _pending = null;

    ref.read(routerProvider).go(notificationLocation(target));
  }
}

/// Keeps a push that arrives while the app is in the background or closed,
/// so the Aktivitas tab lists it. Runs in its own isolate: it starts
/// Firebase and opens the database itself.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage remote) async {
  final message = PushMessage.fromRemote(remote);
  if ((message.data['type'] ?? '').isEmpty) return;

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final db = AppDatabase();

  try {
    await db.notificationsDao.insertIfAbsent(message.toCompanion(receivedAt: DateTime.now().toUtc()));
  } on Exception catch (e, st) {
    AppLogger.w('Background push not stored', tag: _tag, error: e, stackTrace: st);
  } finally {
    await db.close();
  }
}

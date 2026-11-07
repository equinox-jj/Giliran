import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/logger/app_logger.dart';

part 'push_service.g.dart';

/// Whether the OS lets the app show notifications.
enum PushPermission() {
  granted,
  denied,
  notDetermined,
}

/// A push as the app sees it: the FCM data map (`type`, `group_id`,
/// `period_id`, `payment_id`, `payout_id`) plus the title and body the
/// worker rendered in the user's language.
class const PushMessage({
  final String? id,
  final Map<String, String> data = const {},
  final String? title,
  final String? body,
  final DateTime? sentAt,
}) {
  factory fromRemote(RemoteMessage message) => PushMessage(
    id: message.messageId,
    data: {for (final MapEntry(:key, :value) in message.data.entries) key: '$value'},
    title: message.notification?.title,
    body: message.notification?.body,
    sentAt: message.sentTime?.toUtc(),
  );

  /// The payload of a local notification, written by [toPayload].
  static PushMessage? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      return PushMessage(
        id: json['id'] as String?,
        data: {
          for (final MapEntry(:key, :value) in (json['data'] as Map<String, dynamic>? ?? {}).entries) key: '$value',
        },
        title: json['title'] as String?,
        body: json['body'] as String?,
        sentAt: DateTime.tryParse(json['sent_at'] as String? ?? ''),
      );
    } on FormatException {
      return null;
    }
  }

  String toPayload() => jsonEncode({
    'id': id,
    'data': data,
    'title': title,
    'body': body,
    'sent_at': sentAt?.toIso8601String(),
  });
}

/// Push notifications: the FCM token, permission, foreground display and
/// taps. [FirebasePushService] is the app's; tests override
/// [pushServiceProvider] with a fake.
abstract interface class PushService() {
  /// Wires FCM and local notifications; call once at startup.
  Future<void> init();

  /// The device's FCM token, or null when FCM is unavailable.
  Future<String?> token();

  Stream<String> get tokenRefreshes;

  /// Pushes that arrive while the app is in the foreground.
  Stream<PushMessage> get received;

  /// Notifications the user tapped while the app was running.
  Stream<PushMessage> get opened;

  /// The notification that launched the app, once.
  Future<PushMessage?> initialMessage();

  Future<PushPermission> permission();

  /// Asks the OS (Android 13+, iOS); returns the resulting state.
  Future<PushPermission> requestPermission();

  /// Opens the app's system settings, where a denied permission is changed.
  Future<void> openSettings();
}

/// [PushService] over `firebase_messaging` and
/// `flutter_local_notifications`. Android shows foreground pushes through a
/// local notification (FCM shows nothing then); iOS presents them itself.
class FirebasePushService() implements PushService {
  static const _tag = 'push';
  static const _channel = AndroidNotificationChannel(
    'giliran_default',
    'Giliran',
    description: 'Iuran, kocokan dan aktivitas grup',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  final _received = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();
  var _ready = false;

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  @override
  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked through FCM, at the moment the app chooses.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final message = PushMessage.fromPayload(response.payload);
        if (message != null) _opened.add(message);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _fcm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((remote) {
      final message = PushMessage.fromRemote(remote);
      _received.add(message);
      if (defaultTargetPlatform == TargetPlatform.android) unawaited(_show(message));
    });
    FirebaseMessaging.onMessageOpenedApp.listen((remote) => _opened.add(PushMessage.fromRemote(remote)));
  }

  Future<void> _show(PushMessage message) async {
    if (message.title == null && message.body == null) return;
    await _local.show(
      id: (message.id ?? message.toPayload()).hashCode & 0x7FFFFFFF,
      title: message.title,
      body: message.body,
      payload: message.toPayload(),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  @override
  Future<String?> token() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS && !await _apnsReady()) {
        // getToken() throws apns-token-not-set until APNs hands one over:
        // no Push Notifications capability, simulator, or still registering.
        AppLogger.w('APNs token not available, skipping FCM token', tag: _tag);
        return null;
      }
      // The worker sends to FCM registration tokens (`PUT /me/push-token`).
      // register()/onRegistered give an installation id for direct send
      // instead, which the backend doesn't use, so the token API stays.
      // ignore: deprecated_member_use
      return await _fcm.getToken();
    } on Exception catch (e, st) {
      // No Play services, no network on first launch, iOS without APNs.
      AppLogger.w('FCM token unavailable', tag: _tag, error: e, stackTrace: st);
      return null;
    }
  }

  /// Waits up to ~3 s for the APNs token, which iOS delivers shortly after
  /// registering for remote notifications.
  Future<bool> _apnsReady() async {
    for (var i = 0; i < 6; i++) {
      if (await _fcm.getAPNSToken() != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  @override
  // ignore: deprecated_member_use, the token API stays (see [token]).
  Stream<String> get tokenRefreshes => _fcm.onTokenRefresh;

  @override
  Stream<PushMessage> get received => _received.stream;

  @override
  Stream<PushMessage> get opened => _opened.stream;

  @override
  Future<PushMessage?> initialMessage() async {
    final remote = await _fcm.getInitialMessage();
    if (remote != null) return PushMessage.fromRemote(remote);
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      return PushMessage.fromPayload(launch?.notificationResponse?.payload);
    }
    return null;
  }

  @override
  Future<PushPermission> permission() async => _map((await _fcm.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async => _map((await _fcm.requestPermission()).authorizationStatus);

  @override
  Future<void> openSettings() => openAppSettings();

  static PushPermission _map(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };
}

@Riverpod(keepAlive: true)
PushService pushService(Ref ref) => FirebasePushService();

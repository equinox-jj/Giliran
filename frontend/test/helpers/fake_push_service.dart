import 'dart:async';

import 'package:giliran/core/services/push_service.dart';

/// A [PushService] without Firebase: tests push messages, taps and token
/// refreshes through the controllers and read what was asked of it.
class FakePushService() implements PushService {
  String? fcmToken = 'fcm-1';
  PushPermission permissionState = PushPermission.granted;
  PushPermission afterRequest = PushPermission.granted;
  PushMessage? launchMessage;
  var initCount = 0;
  var requestCount = 0;
  var settingsOpened = 0;

  final _received = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();
  final _tokens = StreamController<String>.broadcast();

  void receive(PushMessage message) => _received.add(message);

  void tap(PushMessage message) => _opened.add(message);

  void refreshToken(String token) => _tokens.add(token);

  @override
  Future<void> init() async => initCount++;

  @override
  Future<String?> token() async => fcmToken;

  @override
  Stream<String> get tokenRefreshes => _tokens.stream;

  @override
  Stream<PushMessage> get received => _received.stream;

  @override
  Stream<PushMessage> get opened => _opened.stream;

  @override
  Future<PushMessage?> initialMessage() async => launchMessage;

  @override
  Future<PushPermission> permission() async => permissionState;

  @override
  Future<PushPermission> requestPermission() async {
    requestCount++;
    return permissionState = afterRequest;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

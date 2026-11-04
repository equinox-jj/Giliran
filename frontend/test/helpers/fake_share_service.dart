import 'dart:typed_data';
import 'dart:ui';

import 'package:giliran/core/services/share_service.dart';

/// Records what the app shares or opens instead of leaving the app.
class FakeShareService() implements ShareService {
  final sharedTexts = <String>[];
  final openedUrls = <Uri>[];
  final whatsApp = <({String? phone, String text})>[];

  @override
  Future<void> shareText(String text, {Rect? origin}) async => sharedTexts.add(text);

  @override
  Future<void> shareImage(Uint8List png, {String? text, Rect? origin}) async {}

  @override
  Future<bool> openWhatsApp({String? phone, required String text}) async {
    whatsApp.add((phone: phone, text: text));
    return true;
  }

  @override
  Future<bool> openUrl(Uri uri) async {
    openedUrls.add(uri);
    return true;
  }
}

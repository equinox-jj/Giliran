import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/logger/app_logger.dart';

part 'share_service.g.dart';

/// Hands text, images and links to other apps: the system share sheet,
/// WhatsApp through `wa.me`, and the browser. Used by Invite (S16), the claim
/// link sheet (S28) and the public verification fallback (`/v/:code`).
class const ShareService() {
  static const _tag = 'share';

  /// Opens the share sheet with [text]. [origin] anchors the popover on
  /// iPad.
  Future<void> shareText(String text, {Rect? origin}) async {
    await SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin));
  }

  /// Opens the share sheet with a PNG and optional [text].
  Future<void> shareImage(Uint8List png, {String? text, Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: [XFile.fromData(png, mimeType: 'image/png', name: 'giliran.png')],
        sharePositionOrigin: origin,
      ),
    );
  }

  /// Opens WhatsApp with [text], in a chat with [phone] when given. False
  /// when no app could open the link.
  Future<bool> openWhatsApp({String? phone, required String text}) => openUrl(whatsAppUri(phone: phone, text: text));

  /// Opens [uri] outside the app (browser or the app that handles it).
  Future<bool> openUrl(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception catch (e) {
      AppLogger.w('open failed: $e', tag: _tag);
      return false;
    }
  }

  /// `https://wa.me/{digits}?text=…`, with the phone reduced to its digits
  /// (no `+`).
  @visibleForTesting
  static Uri whatsAppUri({String? phone, required String text}) {
    final digits = phone?.replaceAll(RegExp(r'\D'), '') ?? '';
    return Uri.https('wa.me', digits.isEmpty ? '/' : '/$digits', {'text': text});
  }
}

@Riverpod(keepAlive: true)
ShareService shareService(Ref ref) => const ShareService();

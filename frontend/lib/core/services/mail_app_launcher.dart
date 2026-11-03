import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/logger/app_logger.dart';

part 'mail_app_launcher.g.dart';

/// Opens the device's mail app on its inbox, for "Buka aplikasi email" on
/// the email code screens (8.35). Android starts the default `APP_EMAIL`
/// app; iOS opens Apple Mail through `message://`.
class const MailAppLauncher() {
  static const _tag = 'mail';

  /// Opens the inbox. False when no mail app could be opened, so the screen
  /// can tell the user to open it themselves.
  Future<bool> open() async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          const intent = AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.APP_EMAIL',
            flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
          );
          if (await intent.canResolveActivity() != true) return false;
          await intent.launch();
          return true;
        case TargetPlatform.iOS:
          return await launchUrl(Uri.parse('message://'));
        default:
          return false;
      }
    } on Exception catch (e) {
      AppLogger.w('open failed: $e', tag: _tag);
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
MailAppLauncher mailAppLauncher(Ref ref) => const MailAppLauncher();

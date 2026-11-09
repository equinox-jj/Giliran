import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/utils/licenses.dart';
import 'app/push_controller.dart';
import 'core/utils/logger/app_logger.dart';
import 'firebase_options.dart';

/// Initializes logging, Firebase (push and crash reporting), the bundled
/// licenses and Indonesian (`id_ID`) date formatting, then runs [GiliranApp]
/// inside a Riverpod [ProviderScope].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _initCrashReporting();
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  registerAppLicenses();
  await initializeDateFormatting('id_ID');

  runApp(
    const ProviderScope(
      child: GiliranApp(),
    ),
  );
}

/// Sends uncaught Flutter and platform errors to Crashlytics. Collection is
/// off in debug builds so local crashes stay in the console.
Future<void> _initCrashReporting() async {
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    presentError?.call(details);
    crashlytics.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}

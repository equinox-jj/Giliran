import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/push_controller.dart';
import 'core/utils/logger/app_logger.dart';
import 'firebase_options.dart';

/// Initializes logging, Firebase (push) and Indonesian (`id_ID`) date
/// formatting, then runs [GiliranApp] inside a Riverpod [ProviderScope].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  await initializeDateFormatting('id_ID');

  runApp(
    const ProviderScope(
      child: GiliranApp(),
    ),
  );
}

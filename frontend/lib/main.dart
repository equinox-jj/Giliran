import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/logger/app_logger.dart';

/// Initializes logging and Indonesian (`id_ID`) date formatting, then runs
/// [GiliranApp] inside a Riverpod [ProviderScope].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
  await initializeDateFormatting('id_ID');

  runApp(
    const ProviderScope(
      child: GiliranApp(),
    ),
  );
}

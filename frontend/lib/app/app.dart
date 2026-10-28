import 'package:material_ui/material_ui.dart';

import '../core/themes/themes.dart';
import 'component_gallery_page.dart';

class GiliranApp extends StatelessWidget {
  const GiliranApp({super.key, this.themeMode = ThemeMode.system});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Giliran',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // Temporary home until the router lands.
      home: const ComponentGalleryPage(),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/widgets.dart';

/// Placeholder until the Beranda screen is built.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: 'Beranda', showBack: false),
      body: const EmptyState(
        title: 'Beranda',
        message: 'Grup arisanmu akan tampil di sini.',
      ),
    );
  }
}

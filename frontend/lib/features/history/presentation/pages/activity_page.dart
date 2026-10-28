import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/widgets.dart';

/// Placeholder until the Aktivitas screen is built.
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: 'Aktivitas', showBack: false),
      body: const EmptyState(
        title: 'Aktivitas',
        message: 'Riwayat aktivitas akan tampil di sini.',
      ),
    );
  }
}

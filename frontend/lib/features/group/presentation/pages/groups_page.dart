import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/widgets.dart';

/// Placeholder until the Grup screen is built.
class const GroupsPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: 'Grup', showBack: false),
      body: const EmptyState(
        title: 'Grup',
        message: 'Daftar grup akan tampil di sini.',
      ),
    );
  }
}

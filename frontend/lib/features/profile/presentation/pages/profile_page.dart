import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/widgets.dart';

/// Placeholder until the Profil screen is built.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: 'Profil', showBack: false),
      body: const EmptyState(
        title: 'Profil',
        message: 'Pengaturan profil akan tampil di sini.',
      ),
    );
  }
}

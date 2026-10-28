import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/widgets.dart';

/// Placeholder until the Masuk screen is built.
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: 'Masuk', showBack: false),
      body: const EmptyState(
        title: 'Masuk',
        message: 'Masuk dengan email untuk mulai.',
      ),
    );
  }
}

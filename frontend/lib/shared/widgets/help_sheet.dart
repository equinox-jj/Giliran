import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'adaptive/app_sheet.dart';
import 'app_button.dart';

/// Explains a concept in plain language: `title`, 2–4 short `bodyLg`
/// paragraphs, an optional small diagram, and one ghost "Mengerti" button.
Future<void> showHelpSheet(
  BuildContext context, {
  required String title,
  required List<String> paragraphs,
  Widget? diagram,
  String dismissLabel = 'Mengerti',
}) => showAppSheet<void>(
  context,
  builder: (context) => _HelpSheet(
    title: title,
    paragraphs: paragraphs,
    diagram: diagram,
    dismissLabel: dismissLabel,
  ),
);

class _HelpSheet extends StatelessWidget {
  const _HelpSheet({
    required this.title,
    required this.paragraphs,
    required this.diagram,
    required this.dismissLabel,
  });

  final String title;
  final List<String> paragraphs;
  final Widget? diagram;
  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return AppSheetBody(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in paragraphs) ...[
            Text(p, style: t.bodyLg.copyWith(color: c.textSecondary)),
            const SizedBox(height: AppSpace.s3),
          ],
          if (diagram case final diagram?) ...[
            const SizedBox(height: AppSpace.s2),
            Center(child: ExcludeSemantics(child: diagram)),
            const SizedBox(height: AppSpace.s4),
          ],
          AppButton.ghost(
            label: dismissLabel,
            block: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/widgets/widgets.dart';

/// The Beranda headline (S10), built from the data: dues waiting, all
/// settled, or no groups yet.
class const HomeHeadline({
  super.key,
  required final String firstName,
  required final int groupCount,
  required final int openDues,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = groupCount == 0
        ? l10n.homeHeadlineEmpty
        : openDues > 0
        ? l10n.homeHeadlineDue(firstName, openDues)
        : l10n.homeHeadlineClear;
    return HeadlineText(text);
  }
}

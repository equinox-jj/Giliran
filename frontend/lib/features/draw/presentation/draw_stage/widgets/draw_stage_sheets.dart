import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../member/domain/entities/member.dart';

/// The full commitment hash with a copy button, so members can screenshot
/// or keep it before the draw.
Future<void> showCommitmentSheet(BuildContext context, {required String hash}) => showAppSheet<void>(
  context,
  builder: (context) => _CommitmentSheet(hash: hash),
);

/// The slots taking part in the draw, by slot number.
Future<void> showEligibleSheet(BuildContext context, {required List<Member> eligible}) => showAppSheet<void>(
  context,
  builder: (context) => _EligibleSheet(eligible: eligible),
);

/// "Cara kerja kocokan" (8.31): commit, reveal, pick.
Future<void> showDrawHelpSheet(BuildContext context) {
  final l10n = context.l10n;
  return showHelpSheet(
    context,
    title: l10n.drawHelpButton,
    paragraphs: [l10n.drawHelpCommit, l10n.drawHelpReveal, l10n.drawHelpPick],
  );
}

class const _CommitmentSheet({required final String hash}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return AppSheetBody(
      title: l10n.drawCommitmentTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.drawCommitmentBody, style: t.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpace.s4),
          SelectableText(hash, style: t.mono.copyWith(color: c.textPrimary)),
          const SizedBox(height: AppSpace.s4),
          AppButton.secondary(
            label: l10n.copyButton,
            icon: AppIcons.copy,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: hash));
              if (context.mounted) showAppToast(context, l10n.verifyCopied);
            },
          ),
        ],
      ),
    );
  }
}

class const _EligibleSheet({required final List<Member> eligible}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.6;
    return AppSheetBody(
      title: l10n.drawPeopleTitle,
      subtitle: l10n.drawEligibleCount(eligible.length),
      scrollable: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height),
        child: ListView.builder(
          // Bounded by the sheet's max height, so it can size to a short list.
          shrinkWrap: true,
          itemCount: eligible.length,
          itemBuilder: (context, i) {
            final m = eligible[i];
            return AppListRow(
              title: m.displayName ?? '',
              leading: AppAvatar(name: m.displayName ?? '', imageUrl: m.avatarUrl, guest: m.isGuest ?? false),
              trailing: Text(CodeFormatter.slotNo(m.slotNo ?? 0), style: t.mono.copyWith(color: c.textSecondary)),
            );
          },
        ),
      ),
    );
  }
}

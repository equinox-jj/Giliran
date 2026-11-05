import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import 'headline_text.dart';
import 'period_strip.dart';
import 'section_header.dart';
import 'slot_token.dart';

/// One key figure on the Cycle Summary card ("Rp20.000.000" / "Terkumpul").
class const CycleStat({required final String value, required final String label});

/// A row of "Pemenang per periode": "P4 · Bu Rina", its date, and a Bukti
/// Kocok link.
class const CycleWinnerRow({required final String periodId, required final String title, final String? date});

/// The end-of-cycle card (Tikar §9.12) on the group summary: a hero
/// panel in the group tone with the headline, three key figures in
/// `amountLg`, the full Period Strip wrapped (undrawn periods of a closed
/// group as dashed tokens marked "Tidak dikocok") and the winners list with
/// links to each Bukti Kocok.
class const CycleSummaryCard({
  super.key,
  required final String headline,
  final String? subline,
  required final List<CycleStat> stats,
  required final List<PeriodTokenData> tokens,
  required final List<CycleWinnerRow> winners,
  required final ValueChanged<String> onProof,
  final GroupTone? tone,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    final surface = tone?.surface ?? c.hero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: HeadlineText(headline, color: c.textPrimary)),
                if (subline != null) ...[
                  const SizedBox(height: AppSpace.s2),
                  Text(subline!, style: t.body.copyWith(color: c.textSecondary)),
                ],
                const SizedBox(height: AppSpace.s5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in stats) Expanded(child: _Stat(stat: s)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        Wrap(
          spacing: AppSpace.s1,
          runSpacing: AppSpace.s2,
          children: [
            for (final token in tokens) _Token(token: token, undrawnLabel: l10n.summaryNotDrawn),
          ],
        ),
        if (winners.isNotEmpty) ...[
          SectionHeader(title: l10n.summaryWinnersTitle),
          for (final w in winners) _WinnerRow(row: w, onProof: () => onProof(w.periodId)),
        ],
      ],
    );
  }
}

class const _Stat({required final CycleStat stat}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(stat.value, style: t.amountLg.copyWith(color: c.textPrimary)),
          ),
          Text(stat.label, style: t.caption.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

class const _Token({required final PeriodTokenData token, required final String undrawnLabel}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final undrawn = token.state == SlotTokenState.upcoming;
    return SizedBox(
      width: SlotToken.hitSize + AppSpace.s4,
      child: Column(
        children: [
          SlotToken(
            periodNo: token.periodNo,
            state: token.state,
            winnerName: token.winnerName,
            winnerAvatarUrl: token.winnerAvatarUrl,
            iWon: token.iWon,
          ),
          if (undrawn)
            ExcludeSemantics(
              child: Text(
                undrawnLabel,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(context).micro.copyWith(color: context.colors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class const _WinnerRow({required final CycleWinnerRow row, required final VoidCallback onProof})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    return SizedBox(
      height: AppSizes.rowH,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: t.label.copyWith(color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (row.date != null) Text(row.date!, style: t.caption.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          AppTextButton(label: l10n.scheduleProofLink, onPressed: onProof),
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import 'slot_token.dart';

/// One token of the [PeriodStrip].
@immutable
class const PeriodTokenData({
  required final String id,
  required final int periodNo,
  required final SlotTokenState state,
  final String? winnerName,
  final String? winnerAvatarUrl,
  final bool iWon = false,
});

/// The cycle of turns (Tikar §9.2): one Slot Token per period with "P1",
/// "P2"… above. On phones it scrolls and centers the current period; from
/// medium it shows every period, wrapping into rows.
class const PeriodStrip({
  super.key,
  required final List<PeriodTokenData> periods,
  final String? selectedPeriodId,
  required final ValueChanged<String> onSelect,
}) extends StatefulWidget {
  /// Width of one token column, label included.
  static const itemExtent = 52.0;

  @override
  State<PeriodStrip> createState() => _PeriodStripState();
}

class _PeriodStripState() extends State<PeriodStrip> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerCurrent());
  }

  @override
  void didUpdateWidget(PeriodStrip old) {
    super.didUpdateWidget(old);
    if (_currentIndex(old.periods) != _currentIndex(widget.periods)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerCurrent());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static int _currentIndex(List<PeriodTokenData> periods) =>
      periods.indexWhere((p) => p.state == SlotTokenState.current);

  void _centerCurrent() {
    if (!mounted || !_scroll.hasClients) return;
    final index = _currentIndex(widget.periods);
    if (index < 0) return;
    final viewport = _scroll.position.viewportDimension;
    final target = index * PeriodStrip.itemExtent - (viewport - PeriodStrip.itemExtent) / 2;
    _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final compact = context.isCompact;
    final periods = widget.periods;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(compact ? AppRadius.full : AppRadius.lg)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2, vertical: AppSpace.s2),
        child: compact
            ? SizedBox(
                height: _TokenColumn.height,
                child: ListView.builder(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  itemExtent: PeriodStrip.itemExtent,
                  itemCount: periods.length,
                  itemBuilder: (context, i) => _TokenColumn(
                    data: periods[i],
                    selected: periods[i].id == widget.selectedPeriodId,
                    onSelect: widget.onSelect,
                  ),
                ),
              )
            : Wrap(
                children: [
                  // At most 50 periods, laid out at once to wrap.
                  for (final p in periods)
                    SizedBox(
                      width: PeriodStrip.itemExtent,
                      child: _TokenColumn(
                        data: p,
                        selected: p.id == widget.selectedPeriodId,
                        onSelect: widget.onSelect,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class const _TokenColumn({
  required final PeriodTokenData data,
  required final bool selected,
  required final ValueChanged<String> onSelect,
}) extends StatelessWidget {
  static const height = 66.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final current = data.state == SlotTokenState.current;
    return SizedBox(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              context.l10n.periodShort(data.periodNo),
              style: t.micro.copyWith(color: current ? c.textPrimary : c.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpace.s1),
          SlotToken(
            periodNo: data.periodNo,
            state: data.state,
            winnerName: data.winnerName,
            winnerAvatarUrl: data.winnerAvatarUrl,
            iWon: data.iWon,
            selected: selected,
            onTap: () => onSelect(data.id),
          ),
        ],
      ),
    );
  }
}

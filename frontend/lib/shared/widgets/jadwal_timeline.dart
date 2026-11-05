import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'dashed_border.dart';
import 'tikar_hatch_painter.dart';

/// How a period's bar is filled on the Jadwal timeline.
enum JadwalBarFill() {
  /// Drawn: solid in the winner's tone.
  drawn,

  /// Open: kunyit with the tikar hatch until it is drawn.
  open,

  /// Not started: a dashed outline.
  upcoming,
}

/// One row of the Jadwal timeline. [start] and [end] are positions along
/// the axis from 0 to 1.
class const JadwalBar({
  required final int periodNo,
  required final JadwalBarFill fill,
  required final double start,
  required final double end,
  required final String label,
  required final String semanticsLabel,

  /// Fill of a drawn bar; falls back to `text.primary`.
  final Color? tone,
});

/// A labelled mark on the axis, such as a month boundary.
class const JadwalTick({required final double at, required final String label});

/// The cycle as a Gantt (Tikar §9.5): one bar per period, five rows visible
/// with the rest scrolling, and a 1.5 px ink today line topped by a pill
/// with the cycle completion ("40%"). Used by the Jadwal tab.
class const JadwalTimeline({
  super.key,
  required final List<JadwalBar> bars,
  required final double? todayAt,
  required final String todayLabel,
  final List<JadwalTick> ticks = const [],
}) extends StatelessWidget {
  static const todayLineKey = Key('jadwal-today-line');
  static const visibleRows = 5;
  static const rowExtent = 36.0;
  static const _barHeight = 20.0;
  static const _pillHeight = 24.0;
  static const _tickHeight = 18.0;

  @override
  Widget build(BuildContext context) {
    final top = _pillHeight + AppSpace.s1 + (ticks.isEmpty ? 0 : _tickHeight);
    final rows = math.min(bars.length, visibleRows);
    return SizedBox(
      height: top + rows * rowExtent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final at = todayAt;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (ticks.isNotEmpty)
                Positioned(
                  top: _pillHeight + AppSpace.s1,
                  left: 0,
                  right: 0,
                  height: _tickHeight,
                  child: _Ticks(ticks: ticks, width: width),
                ),
              Positioned.fill(
                top: top,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemExtent: rowExtent,
                  itemCount: bars.length,
                  itemBuilder: (context, i) => _BarRow(bar: bars[i], width: width),
                ),
              ),
              if (at != null) ...[
                Positioned(
                  key: todayLineKey,
                  top: _pillHeight / 2,
                  bottom: 0,
                  left: (at * width - AppStroke.ink / 2).clamp(0.0, math.max(0.0, width - AppStroke.ink)),
                  width: AppStroke.ink,
                  child: IgnorePointer(child: ColoredBox(color: context.colors.ink)),
                ),
                Positioned(
                  top: 0,
                  height: _pillHeight,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment(at.clamp(0.0, 1.0) * 2 - 1, 0),
                      child: _TodayPill(label: todayLabel),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class const _TodayPill({required final String label}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
      decoration: ShapeDecoration(color: c.ink, shape: AppShapes.pill),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTextStyles.of(context).micro.copyWith(color: c.page, fontFeatures: AppTextStyles.tabularFigures),
      ),
    );
  }
}

class const _Ticks({required final List<JadwalTick> ticks, required final double width}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.of(context).micro.copyWith(color: context.colors.textTertiary);
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final tick in ticks)
            Positioned(
              left: tick.at * width,
              top: 0,
              child: Text(tick.label, style: style),
            ),
        ],
      ),
    );
  }
}

class const _BarRow({required final JadwalBar bar, required final double width}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppTextStyles.of(context).caption.copyWith(color: c.textSecondary);
    final left = bar.start * width;
    final barWidth = math.max(AppSpace.s1, (bar.end - bar.start) * width);
    // The label sits after the bar, or before it once the bar is in the
    // right part of the axis, so it never runs off the edge.
    final labelBefore = bar.end > 0.6;
    return Semantics(
      label: bar.semanticsLabel,
      container: true,
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left,
              width: barWidth,
              top: (JadwalTimeline.rowExtent - JadwalTimeline._barHeight) / 2,
              height: JadwalTimeline._barHeight,
              child: _BarFill(fill: bar.fill, tone: bar.tone),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: labelBefore ? 0 : left + barWidth + AppSpace.s2,
              right: labelBefore ? width - left + AppSpace.s2 : 0,
              child: Align(
                alignment: labelBefore ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                child: Text(bar.label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _BarFill({required final JadwalBarFill fill, required final Color? tone}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const radius = BorderRadius.all(Radius.circular(AppRadius.xs));
    return switch (fill) {
      JadwalBarFill.drawn => DecoratedBox(
        decoration: BoxDecoration(color: tone ?? c.textPrimary, borderRadius: radius),
      ),
      JadwalBarFill.open => TikarHatch(
        color: c.ink.withValues(alpha: 0.35),
        background: c.turn,
        borderRadius: radius,
        child: const SizedBox.expand(),
      ),
      JadwalBarFill.upcoming => DashedBorder(color: c.borderStrong, radius: AppRadius.xs),
    };
  }
}

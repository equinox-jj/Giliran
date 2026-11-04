import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_doodles.dart';
import '../../core/constants/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import '../../core/utils/code_formatter.dart';
import 'avatar.dart';
import 'circle_icon_button.dart';
import 'doodle.dart';
import 'pressable.dart';

/// The draw stage (Tikar §9.8): a full-bleed group-tone panel with the
/// kaleng in the middle and the eligible slots orbiting it (a static grid
/// with reduced motion), the commitment line, and the 88 px Kocok button
/// between "Lihat peserta" and "Cara kerja kocokan".
///
/// Fixed-order groups pass [featured] (the next person in order) instead of
/// an orbit and no [commitmentHash]. Bumping [shakeToken] plays the kaleng
/// shake: 3 oscillations in 600 ms with 3 light haptics (haptics only with
/// reduced motion). A null [onDraw] disables the button; [showDrawButton]
/// false hides it (members watch).
class const DrawStage({
  super.key,
  required final GroupTone tone,

  /// Eligible slots, in slot order.
  required final List<AvatarData> people,
  final AvatarData? featured,
  final String? commitmentHash,
  final VoidCallback? onCommitmentTap,
  final bool showDrawButton = true,

  /// "Kocok" by default; "Tetapkan giliran" for fixed order.
  final String? drawLabel,
  final VoidCallback? onDraw,
  final VoidCallback? onPeople,
  final VoidCallback? onHelp,
  final int shakeToken = 0,
}) extends StatefulWidget {
  /// Total length of the kaleng shake.
  static const shakeDuration = Duration(milliseconds: 600);

  /// Orbit slots shown at most; the rest are summed in the caption.
  static const maxOrbit = 10;

  @override
  State<DrawStage> createState() => _DrawStageState();
}

class _DrawStageState() extends State<DrawStage> with TickerProviderStateMixin {
  late final _orbit = AnimationController(vsync: this, duration: const Duration(seconds: 40));
  late final _shake = AnimationController(vsync: this, duration: DrawStage.shakeDuration);
  final _hapticTimers = <Timer>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _orbit.stop();
    } else if (!_orbit.isAnimating) {
      unawaited(_orbit.repeat());
    }
  }

  @override
  void didUpdateWidget(DrawStage old) {
    super.didUpdateWidget(old);
    if (widget.shakeToken != old.shakeToken) _playShake();
  }

  void _playShake() {
    for (final t in _hapticTimers) {
      t.cancel();
    }
    _hapticTimers
      ..clear()
      ..addAll([
        for (var i = 0; i < 3; i++)
          Timer(DrawStage.shakeDuration * (i / 3), () => unawaited(HapticFeedback.lightImpact())),
      ]);
    if (!AppMotion.reduced(context)) unawaited(_shake.forward(from: 0));
  }

  @override
  void dispose() {
    for (final t in _hapticTimers) {
      t.cancel();
    }
    _orbit.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reduced = AppMotion.reduced(context);
    final hash = widget.commitmentHash;
    final kaleng = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        // Three full swings that settle as the shake ends.
        final angle = math.sin(t * 3 * 2 * math.pi) * 0.14 * (1 - t);
        return Transform.rotate(angle: angle, child: child);
      },
      child: Doodle(AppDoodles.kaleng, size: 112, color: widget.tone.accent),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: l10n.drawStageSemantics(widget.featured == null ? widget.people.length : 1),
          child: Container(
            height: 300,
            decoration: ShapeDecoration(color: widget.tone.surface, shape: AppShapes.squircle(AppRadius.xl)),
            clipBehavior: Clip.antiAlias,
            child: switch (widget.featured) {
              final featured? => _Featured(person: featured, tone: widget.tone, kaleng: kaleng),
              null when reduced => _Grid(people: widget.people, tone: widget.tone, kaleng: kaleng),
              null => _Orbit(people: widget.people, tone: widget.tone, orbit: _orbit, kaleng: kaleng),
            },
          ),
        ),
        if (hash != null) ...[
          const SizedBox(height: AppSpace.s3),
          _CommitmentLine(hash: hash, onTap: widget.onCommitmentTap),
        ],
        const SizedBox(height: AppSpace.s5),
        _Controls(
          showDrawButton: widget.showDrawButton,
          drawLabel: widget.drawLabel ?? l10n.drawButton,
          onDraw: widget.onDraw,
          onPeople: widget.onPeople,
          onHelp: widget.onHelp,
        ),
      ],
    );
  }
}

class const _Orbit({
  required final List<AvatarData> people,
  required final GroupTone tone,
  required final Animation<double> orbit,
  required final Widget kaleng,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shown = people.take(DrawStage.maxOrbit).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        const size = AppSizes.avatarMd;
        final radius = math.min(constraints.maxWidth, constraints.maxHeight) / 2 - size / 2 - AppSpace.s3;
        return AnimatedBuilder(
          animation: orbit,
          builder: (context, child) {
            final turn = orbit.value * 2 * math.pi;
            return Stack(
              children: [
                Center(child: child),
                for (final (i, p) in shown.indexed)
                  if (_position(i, shown.length, center, radius, turn) case final at)
                    Positioned(
                      left: at.dx - size / 2,
                      top: at.dy - size / 2,
                      child: ExcludeSemantics(
                        child: AppAvatar(name: p.name, imageUrl: p.imageUrl, guest: p.guest, size: size, tone: tone),
                      ),
                    ),
              ],
            );
          },
          child: kaleng,
        );
      },
    );
  }

  /// Where the [i]th of [n] avatars sits on the orbit after [turn] radians.
  static Offset _position(int i, int n, Offset center, double r, double turn) {
    final angle = turn + i * 2 * math.pi / n - math.pi / 2;
    return center + Offset(r * math.cos(angle), r * math.sin(angle));
  }
}

class const _Grid({
  required final List<AvatarData> people,
  required final GroupTone tone,
  required final Widget kaleng,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shown = people.take(DrawStage.maxOrbit).toList();
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          kaleng,
          const SizedBox(height: AppSpace.s4),
          ExcludeSemantics(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s2,
              children: [
                for (final p in shown)
                  AppAvatar(name: p.name, imageUrl: p.imageUrl, guest: p.guest, size: AppSizes.avatarSm, tone: tone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class const _Featured({
  required final AvatarData person,
  required final GroupTone tone,
  required final Widget kaleng,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Opacity(opacity: 0.5, child: kaleng),
        const SizedBox(height: AppSpace.s3),
        Text(l10n.drawNextInOrder, style: t.caption.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpace.s2),
        AppAvatar(name: person.name, imageUrl: person.imageUrl, guest: person.guest, size: 64, tone: tone),
        const SizedBox(height: AppSpace.s2),
        Text(person.name, style: t.titleLg.copyWith(color: c.textPrimary)),
      ],
    );
  }
}

class const _CommitmentLine({required final String hash, required final VoidCallback? onTap}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Semantics(
      button: onTap != null,
      label: l10n.drawCommitmentSemantics,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.tapMin),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  l10n.drawCommitment(CodeFormatter.hashShort(hash)),
                  style: t.mono.copyWith(color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class const _Controls({
  required final bool showDrawButton,
  required final String drawLabel,
  required final VoidCallback? onDraw,
  required final VoidCallback? onPeople,
  required final VoidCallback? onHelp,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        CircleIconButton(icon: AppIcons.users, onPressed: onPeople, semanticLabel: l10n.drawPeopleButton),
        if (showDrawButton)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleIconButton.draw(icon: AppIcons.shuffleBold, onPressed: onDraw, semanticLabel: drawLabel),
              const SizedBox(height: AppSpace.s2),
              ExcludeSemantics(
                child: Text(
                  drawLabel,
                  style: t.label.copyWith(color: onDraw == null ? c.textTertiary : c.textPrimary),
                ),
              ),
            ],
          ),
        CircleIconButton(icon: AppIcons.question, onPressed: onHelp, semanticLabel: l10n.drawHelpButton),
      ],
    );
  }
}

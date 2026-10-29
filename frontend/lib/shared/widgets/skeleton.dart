import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'dashed_border.dart';

/// Loading placeholder in the shape of the content it replaces, on
/// `bg.subtle` with a slow 1.2 s shimmer (static under reduced motion).
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.md,
  }) : circle = false;

  const Skeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = 0,
      circle = true;

  /// One text line of [height] (default 14) in a pill.
  const Skeleton.line({super.key, this.width, this.height = 14})
    : radius = AppRadius.full,
      circle = false;

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final highlight = Color.lerp(c.subtle, c.surface, 0.6)!;
    final shape = widget.circle
        ? const BoxDecoration(shape: BoxShape.circle)
        : BoxDecoration(borderRadius: BorderRadius.circular(widget.radius));

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final x = _controller.value * 3 - 1.5;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: shape.copyWith(
              color: c.subtle,
              gradient: AppMotion.reduced(context)
                  ? null
                  : LinearGradient(
                      begin: Alignment(x - 1, 0),
                      end: Alignment(x + 1, 0),
                      colors: [c.subtle, highlight, c.subtle],
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// Rings load as a dashed circle.
class SkeletonRing extends StatelessWidget {
  const SkeletonRing({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DashedBorder.circle(
      color: context.colors.borderStrong,
      child: SizedBox.square(dimension: size),
    ),
  );
}

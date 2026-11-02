import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// Radio card with an explanation (draw method, period type). Selected: 2 px
/// ink border, ink radio, and the icon circle turns ink.
class const ChoiceCard({
  super.key,
  required final String icon,
  required final String title,
  required final String description,
  required final bool selected,
  required final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final duration = AppMotion.reduced(context) ? Duration.zero : AppMotion.quick;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Pressable(
        onTap: onTap,
        isButton: false,
        semanticLabel: '$title. $description',
        shape: AppShapes.squircle(AppRadius.lg),
        child: AnimatedContainer(
          duration: duration,
          padding: const EdgeInsets.all(AppSpace.s4),
          decoration: ShapeDecoration(
            color: c.surface,
            shape: AppShapes.squircle(
              AppRadius.lg,
              side: BorderSide(
                color: selected ? c.textPrimary : c.hairline,
                width: selected ? AppStroke.strong : AppStroke.regular,
              ),
            ),
          ),
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: duration,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? c.inverse : c.subtle,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(
                    icon,
                    size: AppSizes.iconMd,
                    color: selected ? c.textOnInverse : c.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: t.title.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: t.body.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s2),
                  child: AnimatedContainer(
                    duration: duration,
                    width: AppSizes.radio,
                    height: AppSizes.radio,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? c.textPrimary : c.borderStrong,
                        width: selected ? 7 : AppStroke.regular,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One option of a [ChoiceCardGroup].
class const ChoiceOption<T>({
  required final T value,
  required final String icon,
  required final String title,
  required final String description,
}) {}

/// Choice cards stacked on phone, side by side from medium.
class const ChoiceCardGroup<T>({
  super.key,
  required final List<ChoiceOption<T>> options,
  required final T? value,
  required final ValueChanged<T>? onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final o in options)
        ChoiceCard(
          icon: o.icon,
          title: o.title,
          description: o.description,
          selected: o.value == value,
          onTap: onChanged == null ? null : () => onChanged!(o.value),
        ),
    ];
    if (context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.s3),
            cards[i],
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s3),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

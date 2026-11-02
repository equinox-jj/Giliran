import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'app_button.dart';

/// Empty state: centered column, max 360 wide: illustration (max 200 high),
/// `title.lg` headline, a short `body` explanation and up to two buttons.
/// [compact] (inside tabs and panes) shrinks the illustration to 120 and
/// keeps one secondary button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.illustration,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
  });

  final String title;
  final String? message;

  /// A decorative doodle (SVG), excluded from semantics.
  final Widget? illustration;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final artSize = compact ? 120.0 : 200.0;

    final buttons = <Widget>[
      if (compact) ...[
        if (primaryLabel != null) AppButton.secondary(label: primaryLabel!, onPressed: onPrimary),
      ] else ...[
        if (primaryLabel != null) AppButton(label: primaryLabel!, onPressed: onPrimary, block: true),
        if (secondaryLabel != null)
          AppButton.secondary(
            label: secondaryLabel!,
            onPressed: onSecondary,
            block: true,
          ),
      ],
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? AppSpace.s6 : AppSpace.s12,
            horizontal: AppSpace.s3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (illustration != null) ...[
                ExcludeSemantics(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: artSize,
                      maxWidth: artSize,
                    ),
                    child: illustration,
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
              ],
              Text(
                title,
                style: t.titleLg.copyWith(color: c.textPrimary),
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpace.s2),
                Text(
                  message!,
                  style: t.body.copyWith(color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
              if (buttons.isNotEmpty) const SizedBox(height: AppSpace.s5),
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpace.s2),
                buttons[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

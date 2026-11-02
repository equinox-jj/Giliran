import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'app_text_field.dart';

/// Search pill: 52 high on `bg.subtle` with a leading magnifying glass.
class const SearchField({
  super.key,
  required final TextEditingController controller,
  final String hint = 'Cari',
  final ValueChanged<String>? onChanged,
  final bool autofocus = false,
}) extends StatefulWidget {
  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState() extends State<SearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.full),
      borderSide: BorderSide.none,
    );

    return SizedBox(
      height: AppSizes.searchH,
      child: TextField(
        controller: widget.controller,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: t.bodyLg.copyWith(color: c.textPrimary),
        decoration: InputDecoration(
          hintText: widget.hint,
          filled: true,
          fillColor: c.subtle,
          constraints: const BoxConstraints(minHeight: AppSizes.searchH),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: pill,
          enabledBorder: pill,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
            borderSide: BorderSide(
              color: c.textPrimary,
              width: AppStroke.strong,
            ),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpace.s4,
              end: AppSpace.s2,
            ),
            child: AppIcon(
              AppIcons.magnifyingGlass,
              size: AppSizes.iconMd,
              color: c.textSecondary,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : FieldClearButton(
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged?.call('');
                  },
                ),
        ),
      ),
    );
  }
}

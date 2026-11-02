import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_sizes.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the light and dark [ThemeData] from the Tikar colors and type scale.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, GiliranColors.light);

  static ThemeData dark() => _build(Brightness.dark, GiliranColors.dark);

  static ThemeData _build(Brightness b, GiliranColors c) {
    const t = AppTextStyles.phone();

    final scheme = ColorScheme(
      brightness: b,
      primary: c.inverse,
      onPrimary: c.textOnInverse,
      secondary: c.link,
      onSecondary: c.surface,
      tertiary: c.turn,
      onTertiary: AppPalette.kopi900,
      error: c.rejected.fg,
      onError: c.surface,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      outline: c.borderStrong,
      outlineVariant: c.hairline,
      surfaceContainerLowest: c.page,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.subtle,
      inverseSurface: c.inverse,
      onInverseSurface: c.textOnInverse,
      scrim: c.scrim,
      shadow: AppPalette.shadow,
      surfaceTint: Colors.transparent,
    );

    TextStyle colored(TextStyle s, [Color? color]) => s.copyWith(color: color ?? c.textPrimary);

    final textTheme = TextTheme(
      displayLarge: colored(t.display),
      displayMedium: colored(t.display),
      displaySmall: colored(t.display),
      headlineLarge: colored(t.headline),
      headlineMedium: colored(t.headline),
      headlineSmall: colored(t.headline),
      titleLarge: colored(t.titleLg),
      titleMedium: colored(t.title),
      titleSmall: colored(t.label),
      bodyLarge: colored(t.bodyLg),
      bodyMedium: colored(t.body),
      bodySmall: colored(t.caption, c.textSecondary),
      labelLarge: colored(t.label),
      labelMedium: colored(t.caption),
      labelSmall: colored(t.micro),
    );

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.page,
      canvasColor: c.page,
      fontFamily: AppFonts.sans,
      textTheme: textTheme,
      extensions: [c],
      // Press feedback is scale + tint, the same on both platforms.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconTheme: IconThemeData(color: c.textPrimary, size: AppSizes.iconLg),
      appBarTheme: AppBarTheme(
        backgroundColor: c.page,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: AppSizes.topBarH,
        titleTextStyle: colored(t.title),
        systemOverlayStyle: b == Brightness.light
            ? SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.textPrimary,
        selectionColor: c.info.fg.withValues(alpha: 0.3),
        selectionHandleColor: c.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: true,
        constraints: const BoxConstraints(minHeight: AppSizes.inputH),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s4,
        ),
        hintStyle: colored(t.bodyLg, c.textTertiary),
        helperStyle: colored(t.caption, c.textSecondary),
        errorStyle: colored(t.caption, c.rejected.fg),
        border: border(c.borderStrong, AppStroke.regular),
        enabledBorder: border(c.borderStrong, AppStroke.regular),
        focusedBorder: border(c.textPrimary, AppStroke.strong),
        errorBorder: border(c.rejected.fg, AppStroke.strong),
        focusedErrorBorder: border(c.rejected.fg, AppStroke.strong),
        disabledBorder: border(c.hairline, AppStroke.regular),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.textPrimary,
        linearTrackColor: c.subtle,
        circularTrackColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        modalBackgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.scrim,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        dragHandleSize: const Size(
          AppSizes.sheetHandleW,
          AppSizes.sheetHandleH,
        ),
        constraints: const BoxConstraints(maxWidth: AppSizes.contentMax),
        shape: AppShapes.squircleTop(AppRadius.xl),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        barrierColor: c.scrim,
        elevation: 0,
        shape: AppShapes.squircle(AppRadius.lg),
        titleTextStyle: colored(t.title),
        contentTextStyle: colored(t.body, c.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inverse,
        contentTextStyle: colored(t.body, c.textOnInverse),
        actionTextColor: c.turn,
        elevation: 0,
        shape: AppShapes.pill,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(c.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.paid.fg : c.borderStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: AppShapes.squircle(
          AppRadius.md,
          side: BorderSide(color: c.hairline),
        ),
        textStyle: colored(t.bodyLg),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.hero,
        headerForegroundColor: c.textPrimary,
        todayBorder: BorderSide(color: c.textPrimary, width: AppStroke.ink),
        shape: AppShapes.squircle(AppRadius.lg),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(color: c.inverse, shape: AppShapes.pill),
        textStyle: colored(t.caption, c.textOnInverse),
      ),
    );
  }
}

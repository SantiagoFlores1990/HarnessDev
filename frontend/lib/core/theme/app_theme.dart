import 'package:flutter/material.dart';

import 'app_colors.dart';

const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

/// Estilo con cifras tabulares para importes, calorias y stock.
TextStyle? tabular(TextStyle? style) => style?.copyWith(fontFeatures: tabularFigures);

/// Tema Material 3 claro, azul marino (design-system.md §5).
ThemeData buildLightTheme() {
  const scheme = AppColors.lightScheme;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Segoe UI',
    fontFamilyFallback: const ['Roboto', 'Arial'],
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: const [AppSemanticColors.light],
  );
  final t = base.textTheme;
  final textTheme = t
      .copyWith(
        displaySmall: t.displaySmall?.copyWith(fontSize: 32, height: 40 / 32, fontWeight: FontWeight.w600),
        headlineMedium: t.headlineMedium?.copyWith(fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w600),
        headlineSmall: t.headlineSmall?.copyWith(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w600),
        titleLarge: t.titleLarge?.copyWith(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600),
        titleMedium: t.titleMedium?.copyWith(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600),
        titleSmall: t.titleSmall?.copyWith(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 24 / 16),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 20 / 14),
        bodySmall: t.bodySmall?.copyWith(fontSize: 12, height: 16 / 12),
        labelLarge: t.labelLarge?.copyWith(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),
        labelMedium: t.labelMedium?.copyWith(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600),
      )
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  const semantic = AppSemanticColors.light;
  final focusRing = semantic.focusRing;
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.headlineSmall,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.primary,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer, size: 24),
      unselectedIconTheme: IconThemeData(color: semantic.railUnselected, size: 24),
      selectedLabelTextStyle: textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
      unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(color: semantic.railUnselected),
      useIndicator: true,
      minWidth: 80,
      minExtendedWidth: 240,
      groupAlignment: -1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(scheme.outline),
      enabledBorder: border(scheme.outline),
      focusedBorder: border(focusRing, 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 2),
      labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      helperStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 40),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: scheme.outline, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
      dataRowMinHeight: 52,
      dataRowMaxHeight: 64,
      headingTextStyle: textTheme.titleSmall,
      dividerThickness: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
      width: 480,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
    ),
    focusColor: focusRing.withValues(alpha: 0.16),
    hoverColor: scheme.primary.withValues(alpha: 0.08),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
  );
}

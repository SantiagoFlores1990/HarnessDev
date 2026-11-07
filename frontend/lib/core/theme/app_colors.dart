import 'package:flutter/material.dart';

/// Paleta azul marino de Good Pizza (design-system.md §2). Solo modo claro.
abstract final class AppColors {
  static const navy = Color(0xFF0A2A5E);

  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0A2A5E),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD6E3FF),
    onPrimaryContainer: Color(0xFF001B3F),
    secondary: Color(0xFF3B5A8C),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDCE6F5),
    onSecondaryContainer: Color(0xFF0E1D33),
    tertiary: Color(0xFF8C4A00),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFDCC0),
    onTertiaryContainer: Color(0xFF2E1500),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFF8F9FD),
    onSurface: Color(0xFF1A1C20),
    onSurfaceVariant: Color(0xFF43474F),
    surfaceDim: Color(0xFFD8DAE0),
    surfaceBright: Color(0xFFF8F9FD),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF2F3F9),
    surfaceContainer: Color(0xFFECEEF4),
    surfaceContainerHigh: Color(0xFFE6E8EE),
    surfaceContainerHighest: Color(0xFFE0E3EB),
    outline: Color(0xFF6B707B),
    outlineVariant: Color(0xFFC3C6CF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2E3036),
    onInverseSurface: Color(0xFFF0F0F7),
    inversePrimary: Color(0xFFAAC7FF),
    surfaceTint: Color(0xFF0A2A5E),
  );
}

/// Colores semanticos que Material 3 no define (exito, advertencia, foco, rail).
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.focusRing,
    required this.focusRingOnDark,
    required this.railUnselected,
  });

  final Color success, onSuccess, successContainer, onSuccessContainer;
  final Color warning, onWarning, warningContainer, onWarningContainer;
  final Color focusRing, focusRingOnDark, railUnselected;

  static const light = AppSemanticColors(
    success: Color(0xFF1B6B3A),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFC8F0D4),
    onSuccessContainer: Color(0xFF00210E),
    warning: Color(0xFF8A5A00),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFE8B8),
    onWarningContainer: Color(0xFF2B1B00),
    focusRing: Color(0xFF1F5FD0),
    focusRingOnDark: Color(0xFFFFD166),
    railUnselected: Color(0xFFC9D6EE),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? focusRing,
    Color? focusRingOnDark,
    Color? railUnselected,
  }) =>
      AppSemanticColors(
        success: success ?? this.success,
        onSuccess: onSuccess ?? this.onSuccess,
        successContainer: successContainer ?? this.successContainer,
        onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
        warning: warning ?? this.warning,
        onWarning: onWarning ?? this.onWarning,
        warningContainer: warningContainer ?? this.warningContainer,
        onWarningContainer: onWarningContainer ?? this.onWarningContainer,
        focusRing: focusRing ?? this.focusRing,
        focusRingOnDark: focusRingOnDark ?? this.focusRingOnDark,
        railUnselected: railUnselected ?? this.railUnselected,
      );

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemanticColors(
      success: l(success, other.success),
      onSuccess: l(onSuccess, other.onSuccess),
      successContainer: l(successContainer, other.successContainer),
      onSuccessContainer: l(onSuccessContainer, other.onSuccessContainer),
      warning: l(warning, other.warning),
      onWarning: l(onWarning, other.onWarning),
      warningContainer: l(warningContainer, other.warningContainer),
      onWarningContainer: l(onWarningContainer, other.onWarningContainer),
      focusRing: l(focusRing, other.focusRing),
      focusRingOnDark: l(focusRingOnDark, other.focusRingOnDark),
      railUnselected: l(railUnselected, other.railUnselected),
    );
  }
}

/// Acceso corto a los colores semanticos desde el contexto.
extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  AppSemanticColors get semantic => Theme.of(this).extension<AppSemanticColors>()!;
}

/// Tokens de espaciado (rejilla de 4 px).
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

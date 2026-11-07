import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/core/theme/app_colors.dart';
import 'package:good_pizza/core/theme/contrast.dart';

/// WT-01: recalcula desde el codigo del tema (AppColors / AppSemanticColors) las 45 razones
/// de contraste de design-system.md §2.4 y falla si alguna baja del umbral WCAG 2.1 AA.
void main() {
  const s = AppColors.lightScheme;
  const x = AppSemanticColors.light;

  // (n, nombre, primer plano, fondo, umbral, razon documentada)
  final pairs = <(int, String, Color, Color, double, double)>[
    (1, 'onPrimary/primary', s.onPrimary, s.primary, 4.5, 13.94),
    (2, 'onPrimaryContainer/primaryContainer', s.onPrimaryContainer, s.primaryContainer, 4.5, 13.26),
    (3, 'primary/surface', s.primary, s.surface, 4.5, 13.25),
    (4, 'primary/surfaceContainerLowest', s.primary, s.surfaceContainerLowest, 4.5, 13.94),
    (5, 'primary/primaryContainer', s.primary, s.primaryContainer, 4.5, 10.82),
    (6, 'onSecondary/secondary', s.onSecondary, s.secondary, 4.5, 6.94),
    (7, 'secondary/surface', s.secondary, s.surface, 4.5, 6.59),
    (8, 'onSecondaryContainer/secondaryContainer', s.onSecondaryContainer, s.secondaryContainer, 4.5, 13.42),
    (9, 'onTertiary/tertiary', s.onTertiary, s.tertiary, 4.5, 6.79),
    (10, 'onTertiaryContainer/tertiaryContainer', s.onTertiaryContainer, s.tertiaryContainer, 4.5, 13.28),
    (11, 'onSurface/surface', s.onSurface, s.surface, 4.5, 16.22),
    (12, 'onSurface/surfaceContainerLowest', s.onSurface, s.surfaceContainerLowest, 4.5, 17.06),
    (13, 'onSurface/surfaceContainerLow', s.onSurface, s.surfaceContainerLow, 4.5, 15.41),
    (14, 'onSurface/surfaceContainer', s.onSurface, s.surfaceContainer, 4.5, 14.71),
    (15, 'onSurface/surfaceContainerHigh', s.onSurface, s.surfaceContainerHigh, 4.5, 13.93),
    (16, 'onSurfaceVariant/surface', s.onSurfaceVariant, s.surface, 4.5, 8.86),
    (17, 'onSurfaceVariant/surfaceContainerLowest', s.onSurfaceVariant, s.surfaceContainerLowest, 4.5, 9.32),
    (18, 'onSurfaceVariant/surfaceContainerLow', s.onSurfaceVariant, s.surfaceContainerLow, 4.5, 8.42),
    (19, 'onSurfaceVariant/surfaceContainer', s.onSurfaceVariant, s.surfaceContainer, 4.5, 8.04),
    (20, 'onSurfaceVariant/surfaceContainerHighest', s.onSurfaceVariant, s.surfaceContainerHighest, 4.5, 7.26),
    (21, 'onError/error', s.onError, s.error, 4.5, 6.53),
    (22, 'error/surface', s.error, s.surface, 4.5, 6.21),
    (23, 'error/surfaceContainerLowest', s.error, s.surfaceContainerLowest, 4.5, 6.54),
    (24, 'onErrorContainer/errorContainer', s.onErrorContainer, s.errorContainer, 4.5, 12.77),
    (25, 'error/errorContainer', s.error, s.errorContainer, 4.5, 5.14),
    (26, 'onSuccess/success', x.onSuccess, x.success, 4.5, 6.54),
    (27, 'success/surface', x.success, s.surface, 4.5, 6.22),
    (28, 'onSuccessContainer/successContainer', x.onSuccessContainer, x.successContainer, 4.5, 13.78),
    (29, 'success/successContainer', x.success, x.successContainer, 4.5, 5.26),
    (30, 'onWarning/warning', x.onWarning, x.warning, 4.5, 5.93),
    (31, 'warning/surface', x.warning, s.surface, 4.5, 5.63),
    (32, 'onWarningContainer/warningContainer', x.onWarningContainer, x.warningContainer, 4.5, 13.88),
    (33, 'warning/warningContainer', x.warning, x.warningContainer, 4.5, 4.94),
    (34, 'railUnselected/primary', x.railUnselected, s.primary, 4.5, 9.52),
    (35, 'onInverseSurface/inverseSurface', s.onInverseSurface, s.inverseSurface, 4.5, 11.63),
    (36, 'inversePrimary/inverseSurface', s.inversePrimary, s.inverseSurface, 4.5, 7.74),
    (37, 'outline/surface', s.outline, s.surface, 3.0, 4.72),
    (38, 'outline/surfaceContainerLowest', s.outline, s.surfaceContainerLowest, 3.0, 4.97),
    (39, 'outline/surfaceContainerLow', s.outline, s.surfaceContainerLow, 3.0, 4.49),
    (40, 'focusRing/surface', x.focusRing, s.surface, 3.0, 5.53),
    (41, 'focusRing/surfaceContainerLowest', x.focusRing, s.surfaceContainerLowest, 3.0, 5.82),
    (42, 'focusRing/primaryContainer', x.focusRing, s.primaryContainer, 3.0, 4.52),
    (43, 'focusRing/surfaceContainerHighest', x.focusRing, s.surfaceContainerHighest, 3.0, 4.53),
    (44, 'focusRingOnDark/primary', x.focusRingOnDark, s.primary, 3.0, 9.67),
    (45, 'primaryContainer/primary (indicador del rail)', s.primaryContainer, s.primary, 3.0, 10.82),
  ];

  test('WT-01 hay 45 pares verificados', () => expect(pairs.length, 45));

  for (final (n, name, fg, bg, threshold, documented) in pairs) {
    test('WT-01 contraste #$n $name >= $threshold:1', () {
      final ratio = contrastRatio(fg, bg);
      expect(ratio, greaterThanOrEqualTo(threshold), reason: '$name = ${ratio.toStringAsFixed(2)}');
      // Detecta deriva respecto al calculo manual del diseno (tolerancia 0,15 por redondeos).
      expect(ratio, closeTo(documented, 0.15), reason: '$name difiere de la tabla de diseno ($documented)');
    });
  }

  test('WT-01 la funcion de contraste cumple el caso base blanco/negro = 21:1', () {
    expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)), closeTo(21.0, 0.001));
  });
}

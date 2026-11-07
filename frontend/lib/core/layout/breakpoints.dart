import 'package:flutter/widgets.dart';

/// Rangos de ancho de escritorio (responsive.md §3).
enum DesktopSize { compact, standard, wide }

abstract final class Breakpoints {
  static const double standardMin = 1280;
  static const double wideMin = 1600;
  static const double minRecommendedWidth = 1024;
  static const double minRecommendedHeight = 680;
  static const double maxContentWidth = 1440;

  static DesktopSize of(double width) {
    if (width >= wideMin) return DesktopSize.wide;
    if (width >= standardMin) return DesktopSize.standard;
    return DesktopSize.compact;
  }

  static DesktopSize ofContext(BuildContext context) =>
      of(MediaQuery.sizeOf(context).width);

  /// Columnas de la cuadricula de predefinidas: 2 / 3 / 4.
  static int presetColumns(double width) => switch (of(width)) {
        DesktopSize.compact => 2,
        DesktopSize.standard => 3,
        DesktopSize.wide => 4,
      };

  /// El rail es extendido desde 1280 px.
  static bool railExtended(double width) => width >= standardMin;

  /// Margen de pagina: 24 px (compacto) o 32 px.
  static double pageMargin(double width) => width >= standardMin ? 32 : 24;
}

import 'dart:math' as math;
import 'dart:ui' show Color;

/// Luminancia relativa WCAG 2.1 (linealizacion sRGB).
double relativeLuminance(Color color) {
  double lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(color.r) + 0.7152 * lin(color.g) + 0.0722 * lin(color.b);
}

/// Razon de contraste WCAG entre dos colores: (L1 + 0,05) / (L2 + 0,05) con L1 >= L2.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

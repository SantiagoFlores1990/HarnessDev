import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Ruta del emblema (copiado de docs/03-design/assets).
const String logoAsset = 'assets/brand/good_pizza_logo.svg';

/// Variantes de tamano del logotipo (design-system.md §1).
enum LogoVariant {
  full(128),
  rail(40),
  railCompact(32),
  receipt(56);

  const LogoVariant(this.size);
  final double size;
}

/// Logotipo = emblema SVG + `Text("Good Pizza")`. flutter_svg no renderiza `<text>`,
/// por eso el nombre se compone con un widget de texto real.
class GoodPizzaLogo extends StatelessWidget {
  const GoodPizzaLogo({
    super.key,
    this.variant = LogoVariant.full,
    this.showText = true,
    this.textColor,
    this.vertical = false,
  });

  final LogoVariant variant;
  final bool showText;
  final Color? textColor;

  /// Texto debajo del emblema (login/registro) en lugar de a la derecha.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emblem = SvgPicture.asset(
      logoAsset,
      width: variant.size,
      height: variant.size,
      semanticsLabel: showText ? null : 'Good Pizza',
      excludeFromSemantics: showText,
    );
    if (!showText) return emblem;
    final text = Text(
      'Good Pizza',
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: textColor ?? theme.colorScheme.primary,
      ),
    );
    return vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: [emblem, const SizedBox(height: 8), text])
        : Row(mainAxisSize: MainAxisSize.min, children: [emblem, const SizedBox(width: 12), text]);
  }
}

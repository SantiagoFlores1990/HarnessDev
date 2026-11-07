import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Selector numerico `- [n] +` con limites. Teclado: flechas arriba/abajo o `+`/`-`
/// con el foco dentro del control. Si [limitMessage] no es nulo y se llego al tope,
/// se muestra como texto auxiliar y como tooltip del boton "+".
class PortionStepper extends StatelessWidget {
  const PortionStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
    this.limitMessage,
    this.semanticsLabel,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool enabled;

  /// Texto cuando `value >= max` (p. ej. "Máximo 3 porciones por ingrediente").
  final String? limitMessage;
  final String? semanticsLabel;

  bool get _atMax => value >= max;
  bool get _atMin => value <= min;

  void _inc() {
    if (enabled && !_atMax) onChanged(value + 1);
  }

  void _dec() {
    if (enabled && !_atMin) onChanged(value - 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel,
      value: '$value',
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): _inc,
          const SingleActivator(LogicalKeyboardKey.arrowDown): _dec,
          const SingleActivator(LogicalKeyboardKey.equal): _inc,
          const SingleActivator(LogicalKeyboardKey.numpadAdd): _inc,
          const SingleActivator(LogicalKeyboardKey.minus): _dec,
          const SingleActivator(LogicalKeyboardKey.numpadSubtract): _dec,
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Quitar una',
                  icon: const Icon(Icons.remove),
                  onPressed: enabled && !_atMin ? _dec : null,
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: tabular(theme.textTheme.titleMedium),
                  ),
                ),
                IconButton(
                  tooltip: _atMax && limitMessage != null ? limitMessage : 'Agregar una',
                  icon: const Icon(Icons.add),
                  onPressed: enabled && !_atMax ? _inc : null,
                ),
              ],
            ),
            if (enabled && _atMax && limitMessage != null)
              Text(limitMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Cantidad de pizzas por linea: 1..20.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.enabled = true});
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  static const int maxQuantity = 20;

  @override
  Widget build(BuildContext context) => PortionStepper(
        value: value,
        min: 1,
        max: maxQuantity,
        onChanged: onChanged,
        enabled: enabled,
        limitMessage: 'Máximo 20 pizzas por línea',
        semanticsLabel: 'Cantidad de pizzas',
      );
}

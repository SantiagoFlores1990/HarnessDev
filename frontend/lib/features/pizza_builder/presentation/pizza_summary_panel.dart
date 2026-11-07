import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/display_widgets.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/steppers.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../orders/domain/violation_text.dart';
import '../domain/builder_state.dart';

/// Panel "Tu pizza": seleccion en texto, calorias y precio (del API), mensajes de
/// violacion y acciones.
class PizzaSummaryPanel extends StatelessWidget {
  const PizzaSummaryPanel({
    super.key,
    required this.state,
    required this.ingredients,
    required this.sizeName,
    required this.onQuantity,
    required this.onAdd,
    required this.onCancel,
    required this.onRetryQuote,
  });

  final BuilderState state;
  final List<Ingredient> ingredients;
  final String sizeName;
  final ValueChanged<int> onQuantity;
  final VoidCallback onAdd;
  final VoidCallback onCancel;
  final VoidCallback onRetryQuote;

  String _nameOf(String? id) {
    if (id == null) return '—';
    for (final i in ingredients) {
      if (i.id == id) return i.name;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final quote = state.quote;
    final item = (quote != null && quote.items.isNotEmpty) ? quote.items.first : null;
    final violations = quote?.allViolations ?? const [];
    final toppingIds = state.portions.keys.toList();

    String? blockReason;
    if (!state.canAdd) {
      if (state.quoteError != null) {
        blockReason = 'No se pudo calcular el precio.';
      } else if (state.quoting || quote == null) {
        blockReason = null;
      } else if (violations.isNotEmpty) {
        blockReason = violationText(violations.first);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('TU PIZZA', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Tamaño: $sizeName'),
              Text('Masa: ${_nameOf(state.doughId)}'),
              Text('Salsa: ${_nameOf(state.sauceId)}'),
              const SizedBox(height: AppSpacing.xs),
              Text('Ingredientes (${toppingIds.length} distintos):', style: theme.textTheme.labelLarge),
              if (toppingIds.isEmpty)
                Text('Ninguno todavía', style: theme.textTheme.bodyMedium?.copyWith(color: muted))
              else
                for (final id in toppingIds) Text('· ${_nameOf(id)}  x${state.portionsOf(id)}'),
              const Divider(height: AppSpacing.lg),
              LabeledValueRow(
                label: 'Calorías totales',
                value: Text(item == null ? '—' : formatKcal(item.unitCalories), key: const Key('builder-calories')),
              ),
              LabeledValueRow(
                label: 'Precio de la pizza',
                strong: true,
                value: Text(item == null ? '—' : formatMoney(item.unitPrice), key: const Key('builder-price')),
              ),
              if (item != null && state.quantity > 1)
                LabeledValueRow(
                  label: 'Subtotal de la línea',
                  value: Text(formatMoney(item.lineSubtotal)),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text('(sin IVA)', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                  ),
                  if (state.quoting)
                    Semantics(
                      liveRegion: true,
                      label: 'Calculando',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 6),
                          Text('Calculando…', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                ],
              ),
              Text('El IVA se muestra en el resumen del pedido.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              const SizedBox(height: AppSpacing.md),
              Text('Cantidad de pizzas', style: theme.textTheme.labelLarge),
              Align(
                alignment: Alignment.centerLeft,
                child: QuantityStepper(value: state.quantity, onChanged: onQuantity),
              ),
              Semantics(
                liveRegion: true,
                container: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.quoteError != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      ErrorBanner(
                        message: 'No se pudo calcular el precio.',
                        onRetry: onRetryQuote,
                      ),
                    ],
                    for (final v in violations)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(violationText(v),
                                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Tooltip(
                message: state.canAdd ? 'Agregar al pedido (Ctrl+Enter)' : (blockReason ?? 'Calculando…'),
                child: FilledButton(
                  onPressed: state.canAdd ? onAdd : null,
                  child: const Text('Agregar al pedido'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(onPressed: onCancel, child: const Text('Cancelar')),
            ],
          ),
        ),
      ),
    );
  }
}

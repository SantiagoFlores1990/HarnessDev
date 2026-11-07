import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/display_widgets.dart';
import '../../../core/widgets/steppers.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/domain/violation_text.dart';
import '../domain/builder_state.dart';

/// Fila de masa o salsa: casilla de seleccion exclusiva dentro de su grupo.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.ingredient,
    required this.sizeCode,
    required this.selected,
    required this.onChanged,
    this.locked = false,
    this.groupLabel = '',
  });

  final Ingredient ingredient;
  final String sizeCode;
  final bool selected;
  final ValueChanged<bool> onChanged;

  /// Parte de la receta de una predefinida: marcada y bloqueada.
  final bool locked;
  final String groupLabel;

  @override
  Widget build(BuildContext context) {
    final out = ingredient.isOutOfStock && !selected;
    final enabled = !locked && !out;
    final value = ingredient.valueFor(sizeCode);
    final label = '${ingredient.name}, stock ${ingredient.stock}'
        '${value == null ? '' : ', ${value.price} dólares'}';
    return _RowShell(
      child: Row(
        children: [
          Semantics(
            label: label,
            inMutuallyExclusiveGroup: true,
            child: Checkbox(
              value: selected,
              onChanged: enabled ? (v) => onChanged(v ?? false) : null,
            ),
          ),
          Expanded(
            child: GestureDetector(
              excludeFromSemantics: true,
              onTap: enabled ? () => onChanged(!selected) : null,
              behavior: HitTestBehavior.opaque,
              child: Text(ingredient.name, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (locked && selected)
            const NeutralChip('Parte de la receta', icon: Icons.lock_outline)
          else
            StockBadge(ingredient.stock),
          const SizedBox(width: AppSpacing.sm),
          _PriceKcal(value: value),
        ],
      ),
    );
  }
}

/// Fila de ingrediente del armado: casilla, nombre, stock, precio/kcal y `PortionStepper`.
class IngredientCheckRow extends StatelessWidget {
  const IngredientCheckRow({
    super.key,
    required this.ingredient,
    required this.state,
    required this.onToggle,
    required this.onPortions,
    this.violations = const [],
  });

  final Ingredient ingredient;
  final BuilderState state;
  final VoidCallback onToggle;
  final ValueChanged<int> onPortions;
  final List<Violation> violations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final portions = state.portionsOf(ingredient.id);
    final checked = portions > 0;
    final isRecipe = state.isRecipeIngredient(ingredient.id);
    final out = ingredient.isOutOfStock && !checked;
    final value = ingredient.valueFor(state.sizeCode);

    // Limite de entrada: min(3, stock) en total; nunca por debajo de la receta.
    final recipeMin = isRecipe ? state.recipePortionsOf(ingredient.id) : 1;
    final stockCap = ingredient.stock;
    var max = stockCap < maxPortionsPerIngredient ? stockCap : maxPortionsPerIngredient;
    if (max < recipeMin) max = recipeMin;
    final stockBinds = stockCap < maxPortionsPerIngredient;
    final limitMessage = stockBinds
        ? 'Stock disponible: $stockCap'
        : 'Máximo $maxPortionsPerIngredient porciones por ingrediente';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RowShell(
          child: Row(
            children: [
              Semantics(
                label: '${ingredient.name}, stock ${ingredient.stock}'
                    '${value == null ? '' : ', ${value.price} dólares por porción'}',
                child: Checkbox(
                  value: checked,
                  onChanged: out || isRecipe ? null : (_) => onToggle(),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  excludeFromSemantics: true,
                  onTap: out || isRecipe ? null : onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ingredient.name, style: theme.textTheme.titleMedium),
                      if (isRecipe)
                        Text('Receta: ${state.recipePortionsOf(ingredient.id)} · no se puede quitar',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              StockBadge(ingredient.stock),
              const SizedBox(width: AppSpacing.sm),
              _PriceKcal(value: value),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 168,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: checked
                      ? PortionStepper(
                          value: portions,
                          min: recipeMin,
                          max: max,
                          onChanged: onPortions,
                          limitMessage: limitMessage,
                          semanticsLabel: 'Porciones de ${ingredient.name}',
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        for (final v in violations)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(violationText(v),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ConstrainedBox(constraints: const BoxConstraints(minHeight: 56), child: child);
}

class _PriceKcal extends StatelessWidget {
  const _PriceKcal({required this.value});
  final SizeValue? value;

  @override
  Widget build(BuildContext context) {
    final style = tabular(Theme.of(context).textTheme.bodyMedium);
    return SizedBox(
      width: 150,
      child: Text(
        value == null ? '—' : '+${formatMoney(value!.price)} · ${formatKcal(value!.calories)}',
        style: style,
        textAlign: TextAlign.right,
      ),
    );
  }
}

/// Encabezado de seccion numerada del armado.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(text,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.secondary)),
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

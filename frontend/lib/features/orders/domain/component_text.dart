import 'order_models.dart';

/// Texto de un componente: "Queso mozzarella x3". En predefinidas marca los extras:
/// "(extra)" si no estaba en la receta o "(R receta + E extra)" si la incrementa.
String componentSummary(PricedComponent c, {bool preset = false}) {
  final base = '${c.name} x${c.portions}';
  if (!preset || c.component != 'TOPPING') return base;
  if (c.recipePortions > 0 && c.extraPortions > 0) {
    return '$base (${c.recipePortions} receta + ${c.extraPortions} extra)';
  }
  if (c.recipePortions == 0 && c.extraPortions > 0) return '$base (extra)';
  return base;
}

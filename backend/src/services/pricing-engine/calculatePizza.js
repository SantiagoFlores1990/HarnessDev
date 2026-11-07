import { dec, money, sum } from "../../utils/money.js";
import { isUsable } from "./validatePizza.js";

/**
 * Precio, calorías y subtotales por tarifa de UNA pizza (unidad y línea).
 * Solo suman los componentes usables (cálculo parcial en vivo).
 */
export function calculatePizza(built) {
  const sizeCode = built.size.code;
  const components = built.parts
    .filter((p) => isUsable(p, sizeCode))
    .map((p) => {
      const sv = p.ingredient.sizeValues[sizeCode];
      const price = dec(sv.price);
      return {
        ingredientId: p.ingredientId,
        code: p.ingredient.code,
        name: p.ingredient.name,
        component: p.component,
        categoryCode: p.ingredient.categoryCode,
        recipePortions: p.recipePortions,
        portions: p.portions,
        unitPrice: money(price),
        unitCalories: sv.calories,
        vatRatePercent: money(p.ingredient.vatRatePercent),
        lineAmount: money(price.mul(p.portions)),
        lineCalories: sv.calories * p.portions,
      };
    });
  const unitPrice = sum(components.map((c) => c.lineAmount));
  const unitCalories = components.reduce((a, c) => a + c.lineCalories, 0);
  // Tarifa 0 % -> subtotal 0 %; cualquier otra tarifa (15 %) -> subtotal 15 %.
  const vat0 = sum(
    components
      .filter((c) => dec(c.vatRatePercent).isZero())
      .map((c) => c.lineAmount),
  );
  const vat15 = unitPrice.minus(vat0);
  return {
    components,
    unitPrice: money(unitPrice),
    unitCalories,
    unitSubtotalVat15: money(vat15),
    unitSubtotalVat0: money(vat0),
    lineSubtotal: money(unitPrice.mul(built.quantity)),
    lineCalories: unitCalories * built.quantity,
  };
}

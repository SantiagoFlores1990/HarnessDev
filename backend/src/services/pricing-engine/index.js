import { buildPizza } from "./buildPizza.js";
import { validatePizza } from "./validatePizza.js";
import { calculatePizza } from "./calculatePizza.js";
import { calculateOrder } from "./calculateOrder.js";
import { stockRequirements, stockViolations } from "./stockRequirements.js";

export {
  buildPizza,
  validatePizza,
  calculatePizza,
  calculateOrder,
  stockRequirements,
  stockViolations,
};
export { validateRecipe, presetAvailability } from "./recipe.js";
export { violation } from "./violations.js";

/**
 * Motor único de cotización/confirmación (ADR-002). Puro: no accede a BD ni a HTTP.
 * @param {Array} items PizzaItemInput[]
 * @param {object} catalog { sizes, ingredients: Map, presets: Map }
 * @returns {{valid, violations, items, totals, stock, requirements}}
 */
export function quoteOrder(items, catalog) {
  const builtItems = items.map((item, i) => buildPizza(item, i, catalog));
  const pricedItems = builtItems.map((built) => {
    const violations = [...built.violations, ...validatePizza(built)];
    const calc = calculatePizza(built);
    return {
      index: built.index,
      type: built.type,
      presetPizza: built.presetPizza,
      size: built.size,
      quantity: built.quantity,
      components: calc.components,
      unitPrice: calc.unitPrice,
      unitCalories: calc.unitCalories,
      unitSubtotalVat15: calc.unitSubtotalVat15,
      unitSubtotalVat0: calc.unitSubtotalVat0,
      lineSubtotal: calc.lineSubtotal,
      lineCalories: calc.lineCalories,
      valid: violations.length === 0,
      violations,
    };
  });
  const requirements = stockRequirements(builtItems, catalog);
  const rootViolations = stockViolations(requirements);
  return {
    valid: pricedItems.every((p) => p.valid) && rootViolations.length === 0,
    violations: rootViolations,
    items: pricedItems,
    totals: calculateOrder(pricedItems),
    stock: requirements.map(({ ingredientId, name, required, available }) => ({
      ingredientId,
      name,
      required,
      available,
    })),
    requirements,
  };
}

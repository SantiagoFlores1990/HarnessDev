import { violation } from "./violations.js";

/**
 * Porciones requeridas por ingrediente, agregadas entre todas las líneas
 * (masa y salsa: 1 por pizza; toppings: 1 por porción; × cantidad).
 * @returns {Array<{ingredientId, code, name, required, available}>} ordenado por id
 */
export function stockRequirements(builtItems, catalog) {
  const need = new Map();
  for (const built of builtItems) {
    for (const p of built.parts) {
      need.set(
        p.ingredientId,
        (need.get(p.ingredientId) ?? 0) + p.portions * built.quantity,
      );
    }
  }
  return [...need.entries()]
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([ingredientId, required]) => {
      const ing = catalog.ingredients.get(ingredientId);
      return {
        ingredientId,
        code: ing.code,
        name: ing.name,
        required,
        available: ing.stock,
      };
    });
}

export function stockViolations(requirements) {
  return requirements
    .filter((r) => r.required > r.available)
    .map((r) =>
      violation(
        "INSUFFICIENT_STOCK",
        `No hay stock suficiente de ${r.name}: solicitado ${r.required}, disponible ${r.available}.`,
        {
          ingredientId: r.ingredientId,
          meta: {
            code: r.code,
            name: r.name,
            requested: r.required,
            available: r.available,
          },
        },
      ),
    );
}

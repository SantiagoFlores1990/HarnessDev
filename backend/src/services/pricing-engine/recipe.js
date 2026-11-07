import {
  MAX_PORTIONS_PER_INGREDIENT,
  SIZE_CODES,
} from "../../config/constants.js";
import { violation } from "./violations.js";

/**
 * Valida la receta de una predefinida que define el administrador (INVALID_RECIPE):
 * exactamente 1 masa y 1 salsa con porciones = 1; toppings de otras categorías con 1..3;
 * sin repetidos; SIN mínimo de toppings (S-17). Admite ingredientes inactivos.
 */
export function validateRecipe(recipe, catalog) {
  const out = [];
  const seen = new Set();
  let doughs = 0;
  let sauces = 0;
  for (const r of recipe) {
    const ing = catalog.ingredients.get(r.ingredientId);
    const at = { ingredientId: r.ingredientId };
    if (!ing) {
      out.push(
        violation("INGREDIENT_NOT_FOUND", "Ingrediente inexistente.", at),
      );
      continue;
    }
    if (seen.has(ing.id)) {
      out.push(
        violation(
          "DUPLICATE_INGREDIENT",
          `${ing.name} aparece repetido; usa la cantidad.`,
          at,
        ),
      );
      continue;
    }
    seen.add(ing.id);
    const fixed = ing.categoryCode === "DOUGH" || ing.categoryCode === "SAUCE";
    if (ing.categoryCode === "DOUGH") doughs += 1;
    if (ing.categoryCode === "SAUCE") sauces += 1;
    const max = fixed ? 1 : MAX_PORTIONS_PER_INGREDIENT;
    if (r.portions > max) {
      out.push(
        violation(
          "MAX_PORTIONS_EXCEEDED",
          `Máximo ${max} porción(es) para ${ing.name} (pedido: ${r.portions}).`,
          { ...at, meta: { max, requested: r.portions } },
        ),
      );
    }
  }
  if (doughs === 0)
    out.push(violation("DOUGH_REQUIRED", "La receta necesita una masa."));
  if (sauces === 0)
    out.push(violation("SAUCE_REQUIRED", "La receta necesita una salsa base."));
  if (doughs > 1) {
    out.push(
      violation(
        "INGREDIENT_CATEGORY_NOT_ALLOWED",
        "La receta solo puede tener una masa.",
        {
          meta: { count: doughs },
        },
      ),
    );
  }
  if (sauces > 1) {
    out.push(
      violation(
        "INGREDIENT_CATEGORY_NOT_ALLOWED",
        "La receta solo puede tener una salsa base.",
        {
          meta: { count: sauces },
        },
      ),
    );
  }
  return out;
}

/**
 * Disponibilidad de una predefinida (S-25): inactiva, algún ingrediente inactivo, sin stock para
 * 1 pizza o sin valores de tamaño => no disponible. Devuelve violaciones (vacío = disponible).
 */
export function presetAvailability(preset, catalog) {
  const out = [];
  if (!preset.active) {
    out.push(
      violation(
        "PRESET_INACTIVE",
        `La pizza ${preset.name} no está disponible.`,
      ),
    );
  }
  for (const r of preset.recipe) {
    const ing = catalog.ingredients.get(r.ingredientId);
    const fail = (reason, extra = {}) =>
      out.push(
        violation(
          "PRESET_UNAVAILABLE",
          `La pizza ${preset.name} no está disponible: falta ${ing?.name ?? "un ingrediente"}.`,
          { ingredientId: r.ingredientId, meta: { reason, ...extra } },
        ),
      );
    if (!ing || !ing.active) fail("INACTIVE");
    else if (!SIZE_CODES.every((s) => ing.sizeValues?.[s]))
      fail("MISSING_SIZE_VALUES");
    else if (ing.stock < r.portions)
      fail("OUT_OF_STOCK", { requested: r.portions, available: ing.stock });
  }
  return out;
}

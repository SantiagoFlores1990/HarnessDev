import { MIN_DISTINCT_TOPPINGS } from "../../config/constants.js";
import { violation } from "./violations.js";

/** ¿El componente se puede cobrar? (activo y con valores para el tamaño) */
export const isUsable = (part, sizeCode) =>
  Boolean(part.ingredient.active && part.ingredient.sizeValues?.[sizeCode]);

/**
 * Reglas que dependen del estado del catálogo (activo, valores por tamaño) y mínimo de toppings.
 * Devuelve violaciones adicionales a las de buildPizza.
 */
export function validatePizza(built) {
  const out = [];
  const sizeCode = built.size.code;
  for (const p of built.parts) {
    const at = { itemIndex: built.index, ingredientId: p.ingredientId };
    const unavailable = (reason) =>
      violation(
        "PRESET_UNAVAILABLE",
        `La pizza ${built.presetPizza?.name} no está disponible: falta ${p.ingredient.name}.`,
        { ...at, meta: { reason } },
      );
    if (!p.ingredient.active) {
      out.push(
        p.fromPreset
          ? unavailable("INACTIVE")
          : violation(
              "INGREDIENT_INACTIVE",
              `El ingrediente ${p.ingredient.name} no está disponible.`,
              at,
            ),
      );
    } else if (!p.ingredient.sizeValues?.[sizeCode]) {
      out.push(
        p.fromPreset
          ? unavailable("MISSING_SIZE_VALUES")
          : violation(
              "MISSING_SIZE_VALUES",
              `El ingrediente ${p.ingredient.name} no tiene precio para el tamaño elegido.`,
              at,
            ),
      );
    }
  }
  if (built.type === "CUSTOM") {
    const current = built.parts.filter((p) => p.component === "TOPPING").length;
    if (current < MIN_DISTINCT_TOPPINGS) {
      out.push(
        violation(
          "MIN_TOPPINGS_NOT_MET",
          `Elige al menos ${MIN_DISTINCT_TOPPINGS} ingredientes distintos.`,
          {
            itemIndex: built.index,
            meta: { min: MIN_DISTINCT_TOPPINGS, current },
          },
        ),
      );
    }
  }
  return out;
}

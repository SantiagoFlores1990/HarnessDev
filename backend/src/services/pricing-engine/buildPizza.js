import { MAX_PORTIONS_PER_INGREDIENT } from "../../config/constants.js";
import { violation } from "./violations.js";

const componentOf = (categoryCode) =>
  categoryCode === "DOUGH"
    ? "DOUGH"
    : categoryCode === "SAUCE"
      ? "SAUCE"
      : "TOPPING";

const ORDER = { DOUGH: 0, SAUCE: 1, TOPPING: 2 };

const tooMany = (name, requested, base) =>
  violation(
    "MAX_PORTIONS_EXCEEDED",
    `Máximo ${MAX_PORTIONS_PER_INGREDIENT} porciones por ingrediente (${name}: ${requested}).`,
    { ...base, meta: { max: MAX_PORTIONS_PER_INGREDIENT, requested } },
  );

const notAllowed = (base) =>
  violation(
    "INGREDIENT_CATEGORY_NOT_ALLOWED",
    "La masa y la salsa no se agregan como ingredientes adicionales.",
    base,
  );

const duplicated = (name, base) =>
  violation(
    "DUPLICATE_INGREDIENT",
    `${name} aparece repetido; usa la cantidad.`,
    base,
  );

const notFoundV = (base) =>
  violation("INGREDIENT_NOT_FOUND", "Ingrediente inexistente.", base);

/**
 * Normaliza un PizzaItemInput (CUSTOM o PRESET) a componentes y detecta violaciones estructurales.
 * Pura: solo usa el `catalog` recibido.
 * @returns {{index, type, presetPizza, size, quantity, parts, violations}}
 */
export function buildPizza(item, index, catalog) {
  const violations = [];
  const parts = [];
  const at = (ingredientId) => ({ itemIndex: index, ingredientId });
  const size = catalog.sizes?.[item.sizeCode] ?? {
    code: item.sizeCode,
    name: item.sizeCode,
  };
  const built = {
    index,
    type: item.type,
    presetPizza: null,
    size: { code: size.code, name: size.name },
    quantity: item.quantity,
    parts,
    violations,
  };

  if (item.type === "PRESET") {
    const preset = catalog.presets.get(item.presetPizzaId);
    if (!preset) {
      violations.push(
        violation("PRESET_NOT_FOUND", "La pizza predefinida no existe.", {
          itemIndex: index,
        }),
      );
      return built;
    }
    built.presetPizza = { id: preset.id, code: preset.code, name: preset.name };
    if (!preset.active) {
      violations.push(
        violation(
          "PRESET_INACTIVE",
          `La pizza ${preset.name} no está disponible.`,
          {
            itemIndex: index,
          },
        ),
      );
    }
    for (const r of preset.recipe) {
      const ing = catalog.ingredients.get(r.ingredientId);
      if (!ing) {
        violations.push(notFoundV(at(r.ingredientId)));
        continue;
      }
      parts.push({
        ingredientId: ing.id,
        ingredient: ing,
        component: componentOf(ing.categoryCode),
        recipePortions: r.portions,
        portions: r.portions,
        fromPreset: true,
      });
    }
    const seen = new Set();
    for (const e of item.extras ?? []) {
      const ing = catalog.ingredients.get(e.ingredientId);
      if (!ing) {
        violations.push(notFoundV(at(e.ingredientId)));
        continue;
      }
      if (ing.categoryCode === "DOUGH" || ing.categoryCode === "SAUCE") {
        violations.push(notAllowed(at(ing.id)));
        continue;
      }
      if (seen.has(ing.id)) {
        violations.push(duplicated(ing.name, at(ing.id)));
        continue;
      }
      seen.add(ing.id);
      const existing = parts.find((p) => p.ingredientId === ing.id);
      if (existing) {
        existing.portions += e.portions;
      } else {
        parts.push({
          ingredientId: ing.id,
          ingredient: ing,
          component: "TOPPING",
          recipePortions: 0,
          portions: e.portions,
          fromPreset: false,
        });
      }
    }
    // Receta + extras cuentan juntos para el máximo de 3 porciones.
    for (const p of parts) {
      if (
        p.component === "TOPPING" &&
        p.portions > MAX_PORTIONS_PER_INGREDIENT
      ) {
        violations.push(
          tooMany(p.ingredient.name, p.portions, at(p.ingredientId)),
        );
      }
    }
  } else {
    // CUSTOM
    const pick = (id, spec) => {
      if (!id) {
        violations.push(
          violation(spec.requiredCode, spec.requiredMsg, { itemIndex: index }),
        );
        return;
      }
      const ing = catalog.ingredients.get(id);
      if (!ing) {
        violations.push(notFoundV(at(id)));
        return;
      }
      if (ing.categoryCode !== spec.category) {
        violations.push(violation(spec.invalidCode, spec.invalidMsg, at(id)));
        return;
      }
      parts.push({
        ingredientId: ing.id,
        ingredient: ing,
        component: spec.category,
        recipePortions: 0,
        portions: 1,
        fromPreset: false,
      });
    };
    pick(item.doughId, {
      category: "DOUGH",
      requiredCode: "DOUGH_REQUIRED",
      requiredMsg: "Elige una masa.",
      invalidCode: "INVALID_DOUGH",
      invalidMsg: "El ingrediente elegido no es una masa.",
    });
    pick(item.sauceId, {
      category: "SAUCE",
      requiredCode: "SAUCE_REQUIRED",
      requiredMsg: "Elige una salsa base.",
      invalidCode: "INVALID_SAUCE",
      invalidMsg: "El ingrediente elegido no es una salsa.",
    });

    const seen = new Set();
    for (const t of item.toppings ?? []) {
      const ing = catalog.ingredients.get(t.ingredientId);
      if (!ing) {
        violations.push(notFoundV(at(t.ingredientId)));
        continue;
      }
      if (ing.categoryCode === "DOUGH" || ing.categoryCode === "SAUCE") {
        violations.push(notAllowed(at(ing.id)));
        continue;
      }
      if (seen.has(ing.id)) {
        violations.push(duplicated(ing.name, at(ing.id)));
        continue;
      }
      seen.add(ing.id);
      if (t.portions > MAX_PORTIONS_PER_INGREDIENT) {
        violations.push(tooMany(ing.name, t.portions, at(ing.id)));
      }
      parts.push({
        ingredientId: ing.id,
        ingredient: ing,
        component: "TOPPING",
        recipePortions: 0,
        portions: t.portions,
        fromPreset: false,
      });
    }
  }

  parts.sort((a, b) => ORDER[a.component] - ORDER[b.component]);
  return built;
}

/**
 * Carga desde BD lo que el motor puro necesita (ingredientes con valores por tamaño, recetas,
 * tamaños) y lo convierte al formato `catalog` del pricing-engine.
 * `db` puede ser el cliente Prisma o una transacción.
 */
export const INGREDIENT_INCLUDE = {
  category: true,
  vatRate: true,
  sizeValues: { include: { size: true } },
};

export function toCatalogIngredient(row) {
  const sizeValues = {};
  for (const sv of row.sizeValues) {
    sizeValues[sv.size.code] = {
      price: sv.price.toString(),
      calories: sv.calories,
    };
  }
  return {
    id: row.id,
    code: row.code,
    name: row.name,
    categoryCode: row.category.code,
    active: row.active,
    stock: row.stock,
    vatRatePercent: row.vatRate.ratePercent.toString(),
    sizeValues,
  };
}

export function toCatalogPreset(row) {
  return {
    id: row.id,
    code: row.code,
    name: row.name,
    active: row.active,
    recipe: row.ingredients.map((r) => ({
      ingredientId: r.ingredientId,
      portions: r.portions,
    })),
  };
}

export async function loadSizes(db) {
  const rows = await db.size.findMany({ orderBy: { sortOrder: "asc" } });
  return Object.fromEntries(
    rows.map((s) => [s.code, { id: s.id, code: s.code, name: s.name }]),
  );
}

export function ingredientIdsOf(items) {
  const ids = new Set();
  for (const item of items) {
    if (item.type === "CUSTOM") {
      if (item.doughId) ids.add(item.doughId);
      if (item.sauceId) ids.add(item.sauceId);
      for (const t of item.toppings ?? []) ids.add(t.ingredientId);
    } else {
      for (const e of item.extras ?? []) ids.add(e.ingredientId);
    }
  }
  return ids;
}

/**
 * Catálogo para un conjunto de ítems. Con `lock: true` bloquea las filas de ingredientes con
 * SELECT ... FOR UPDATE ordenado por id (ADR-005); solo válido dentro de una transacción.
 */
export async function loadCatalogForItems(db, items, { lock = false } = {}) {
  const presetIds = [
    ...new Set(
      items.filter((i) => i.type === "PRESET").map((i) => i.presetPizzaId),
    ),
  ];
  const presetRows = presetIds.length
    ? await db.presetPizza.findMany({
        where: { id: { in: presetIds } },
        include: { ingredients: true },
      })
    : [];
  const ids = ingredientIdsOf(items);
  for (const p of presetRows)
    for (const r of p.ingredients) ids.add(r.ingredientId);
  const idList = [...ids].sort();

  if (lock && idList.length) {
    await db.$queryRaw`SELECT id FROM ingredients WHERE id = ANY(${idList}::uuid[]) ORDER BY id FOR UPDATE`;
  }
  const ingredientRows = idList.length
    ? await db.ingredient.findMany({
        where: { id: { in: idList } },
        include: INGREDIENT_INCLUDE,
      })
    : [];

  return {
    sizes: await loadSizes(db),
    ingredients: new Map(
      ingredientRows.map((r) => [r.id, toCatalogIngredient(r)]),
    ),
    presets: new Map(presetRows.map((r) => [r.id, toCatalogPreset(r)])),
  };
}

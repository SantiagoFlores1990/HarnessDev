import { prisma } from "../lib/prisma.js";
import { AppError, notFound } from "../utils/AppError.js";
import { ROLES } from "../config/constants.js";
import {
  quoteOrder,
  presetAvailability,
  validateRecipe,
} from "./pricing-engine/index.js";
import {
  INGREDIENT_INCLUDE,
  loadSizes,
  toCatalogIngredient,
  toCatalogPreset,
} from "./catalogLoader.service.js";

const isAdmin = (user) => user.role === ROLES.ADMIN;

const PRESET_INCLUDE = {
  ingredients: { include: { ingredient: { include: INGREDIENT_INCLUDE } } },
};

const RECIPE_ORDER = { DOUGH: 0, SAUCE: 1 };

/** Vista PresetPizza con precio y calorías por tamaño calculados por el motor (S-18). */
function toPresetView(row, catalog) {
  const entry = toCatalogPreset(row);
  const sizes = Object.values(catalog.sizes);
  const pricesBySize = sizes.map((size) => {
    const [priced] = quoteOrder(
      [
        {
          type: "PRESET",
          presetPizzaId: row.id,
          sizeCode: size.code,
          extras: [],
          quantity: 1,
        },
      ],
      catalog,
    ).items;
    return {
      sizeCode: size.code,
      price: priced.unitPrice,
      calories: priced.unitCalories,
    };
  });
  const unavailableReasons = presetAvailability(entry, catalog);
  const recipe = row.ingredients
    .map((r) => ({
      ingredientId: r.ingredientId,
      code: r.ingredient.code,
      name: r.ingredient.name,
      categoryCode: r.ingredient.category.code,
      portions: r.portions,
      active: r.ingredient.active,
      stock: r.ingredient.stock,
    }))
    .sort(
      (a, b) =>
        (RECIPE_ORDER[a.categoryCode] ?? 2) -
          (RECIPE_ORDER[b.categoryCode] ?? 2) || a.name.localeCompare(b.name),
    );
  return {
    id: row.id,
    code: row.code,
    name: row.name,
    description: row.description ?? null,
    active: row.active,
    sortOrder: row.sortOrder,
    recipe,
    pricesBySize,
    available: unavailableReasons.length === 0,
    unavailableReasons,
  };
}

async function buildViews(db, rows) {
  const sizes = await loadSizes(db);
  const ingredients = new Map();
  const presets = new Map();
  for (const row of rows) {
    presets.set(row.id, toCatalogPreset(row));
    for (const r of row.ingredients) {
      if (!ingredients.has(r.ingredientId))
        ingredients.set(r.ingredientId, toCatalogIngredient(r.ingredient));
    }
  }
  const catalog = { sizes, ingredients, presets };
  return rows.map((row) => toPresetView(row, catalog));
}

export async function list(user, query) {
  const where =
    isAdmin(user) && query.includeInactive === true ? {} : { active: true };
  const rows = await prisma.presetPizza.findMany({
    where,
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    include: PRESET_INCLUDE,
  });
  return buildViews(prisma, rows);
}

async function viewById(db, id) {
  const row = await db.presetPizza.findUnique({
    where: { id },
    include: PRESET_INCLUDE,
  });
  if (!row) return null;
  const [view] = await buildViews(db, [row]);
  return view;
}

export async function getById(user, id) {
  const view = await viewById(prisma, id);
  if (!view || (!isAdmin(user) && !view.active))
    throw notFound("Pizza predefinida no encontrada.");
  return view;
}

async function assertRecipe(db, recipe) {
  const ids = [...new Set(recipe.map((r) => r.ingredientId))];
  const rows = ids.length
    ? await db.ingredient.findMany({
        where: { id: { in: ids } },
        include: INGREDIENT_INCLUDE,
      })
    : [];
  const catalog = {
    ingredients: new Map(rows.map((r) => [r.id, toCatalogIngredient(r)])),
  };
  const violations = validateRecipe(recipe, catalog);
  if (violations.length) {
    throw new AppError(
      422,
      "INVALID_RECIPE",
      `La receta no es válida: ${violations[0].message}`,
      violations,
    );
  }
}

async function assertUnique(db, { code, name }, excludeId) {
  const notSelf = excludeId ? { id: { not: excludeId } } : {};
  if (
    await db.presetPizza.findFirst({
      where: { code, ...notSelf },
      select: { id: true },
    })
  ) {
    throw new AppError(
      409,
      "PRESET_CODE_EXISTS",
      "Ya existe una pizza predefinida con ese código.",
    );
  }
  if (
    await db.presetPizza.findFirst({
      where: { name, ...notSelf },
      select: { id: true },
    })
  ) {
    throw new AppError(
      409,
      "PRESET_NAME_EXISTS",
      "Ya existe una pizza predefinida con ese nombre.",
    );
  }
}

const mapUnique = (err) => {
  if (err?.code !== "P2002") return err;
  const target = String(err.meta?.target ?? "");
  return target.includes("name")
    ? new AppError(
        409,
        "PRESET_NAME_EXISTS",
        "Ya existe una pizza predefinida con ese nombre.",
      )
    : new AppError(
        409,
        "PRESET_CODE_EXISTS",
        "Ya existe una pizza predefinida con ese código.",
      );
};

export async function create(body) {
  await assertRecipe(prisma, body.recipe);
  await assertUnique(prisma, body);
  let row;
  try {
    row = await prisma.presetPizza.create({
      data: {
        code: body.code,
        name: body.name,
        description: body.description ?? null,
        active: body.active ?? true,
        sortOrder: body.sortOrder ?? 0,
        ingredients: {
          create: body.recipe.map((r) => ({
            ingredientId: r.ingredientId,
            portions: r.portions,
          })),
        },
      },
    });
  } catch (err) {
    throw mapUnique(err);
  }
  return viewById(prisma, row.id);
}

export async function update(id, body) {
  if (
    !(await prisma.presetPizza.findUnique({
      where: { id },
      select: { id: true },
    }))
  ) {
    throw notFound("Pizza predefinida no encontrada.");
  }
  await assertRecipe(prisma, body.recipe);
  await assertUnique(prisma, body, id);
  try {
    // La receta se reemplaza completa en una transacción; afecta solo a pedidos nuevos.
    await prisma.$transaction(async (tx) => {
      await tx.presetPizza.update({
        where: { id },
        data: {
          code: body.code,
          name: body.name,
          description: body.description ?? null,
          ...(body.sortOrder !== undefined
            ? { sortOrder: body.sortOrder }
            : {}),
        },
      });
      await tx.presetPizzaIngredient.deleteMany({
        where: { presetPizzaId: id },
      });
      await tx.presetPizzaIngredient.createMany({
        data: body.recipe.map((r) => ({
          presetPizzaId: id,
          ingredientId: r.ingredientId,
          portions: r.portions,
        })),
      });
    });
  } catch (err) {
    throw mapUnique(err);
  }
  return viewById(prisma, id);
}

export async function setActive(id, active) {
  const r = await prisma.presetPizza.updateMany({
    where: { id },
    data: { active },
  });
  if (r.count === 0) throw notFound("Pizza predefinida no encontrada.");
  return viewById(prisma, id);
}

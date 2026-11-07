import { prisma } from "../lib/prisma.js";
import { AppError, notFound } from "../utils/AppError.js";
import { money } from "../utils/money.js";
import { toIso } from "../utils/dates.js";
import { ROLES, SIZE_CODES } from "../config/constants.js";
import { INGREDIENT_INCLUDE } from "./catalogLoader.service.js";

const componentOf = (categoryCode) =>
  categoryCode === "DOUGH"
    ? "DOUGH"
    : categoryCode === "SAUCE"
      ? "SAUCE"
      : "TOPPING";

const codeExists = () =>
  new AppError(
    409,
    "INGREDIENT_CODE_EXISTS",
    "Ya existe un ingrediente con ese código.",
  );

/** Vista Ingredient (api-contract §1.4). El cliente no recibe createdAt/updatedAt. */
export function toIngredientView(row, { admin }) {
  const sizeValues = [...row.sizeValues]
    .sort((a, b) => a.size.sortOrder - b.size.sortOrder)
    .map((sv) => ({
      sizeCode: sv.size.code,
      price: money(sv.price),
      calories: sv.calories,
    }));
  const view = {
    id: row.id,
    code: row.code,
    name: row.name,
    category: { code: row.category.code, name: row.category.name },
    vatRate: {
      code: row.vatRate.code,
      ratePercent: money(row.vatRate.ratePercent),
    },
    active: row.active,
    stock: row.stock,
    sizeValues,
  };
  if (admin) {
    view.createdAt = toIso(row.createdAt);
    view.updatedAt = toIso(row.updatedAt);
  }
  return view;
}

const isAdmin = (user) => user.role === ROLES.ADMIN;

async function fetchRow(db, id) {
  return db.ingredient.findUnique({
    where: { id },
    include: INGREDIENT_INCLUDE,
  });
}

async function view(db, id, user) {
  const row = await fetchRow(db, id);
  if (!row) throw notFound("Ingrediente no encontrado.");
  return toIngredientView(row, { admin: isAdmin(user) });
}

export async function list(user, query) {
  const admin = isAdmin(user);
  const where = {};
  if (!(admin && query.includeInactive === true)) where.active = true;
  if (query.category) where.category = { code: query.category };
  if (query.search) {
    where.OR = [
      { code: { contains: query.search, mode: "insensitive" } },
      { name: { contains: query.search, mode: "insensitive" } },
    ];
  }
  const orderBy = [{ category: { sortOrder: "asc" } }, { name: "asc" }];
  if (query.page === undefined) {
    const rows = await prisma.ingredient.findMany({
      where,
      orderBy,
      include: INGREDIENT_INCLUDE,
    });
    return { data: rows.map((r) => toIngredientView(r, { admin })) };
  }
  const page = query.page;
  const pageSize = query.pageSize ?? 20;
  const [total, rows] = await Promise.all([
    prisma.ingredient.count({ where }),
    prisma.ingredient.findMany({
      where,
      orderBy,
      include: INGREDIENT_INCLUDE,
      skip: (page - 1) * pageSize,
      take: pageSize,
    }),
  ]);
  return {
    data: rows.map((r) => toIngredientView(r, { admin })),
    page,
    pageSize,
    total,
  };
}

export async function getById(user, id) {
  const row = await fetchRow(prisma, id);
  if (!row || (!isAdmin(user) && !row.active))
    throw notFound("Ingrediente no encontrado.");
  return toIngredientView(row, { admin: isAdmin(user) });
}

/** Exige exactamente un valor por cada tamaño (422 MISSING_SIZE_VALUES). */
function assertSizeValues(sizeValues, sizesByCode) {
  const seen = new Set();
  const duplicated = new Set();
  for (const sv of sizeValues) {
    if (seen.has(sv.sizeCode)) duplicated.add(sv.sizeCode);
    seen.add(sv.sizeCode);
  }
  const missing = SIZE_CODES.filter((c) => !seen.has(c));
  if (missing.length || duplicated.size) {
    const details = [{ missing }];
    if (duplicated.size) details[0].duplicated = [...duplicated];
    throw new AppError(
      422,
      "MISSING_SIZE_VALUES",
      "Debes indicar precio y calorías para los 3 tamaños (una sola vez cada uno).",
      details,
    );
  }
  return sizeValues.map((sv) => ({
    sizeId: sizesByCode[sv.sizeCode].id,
    price: sv.price,
    calories: sv.calories,
  }));
}

async function resolveRefs(db, { categoryCode, vatRateCode }) {
  const [category, sizes] = await Promise.all([
    db.ingredientCategory.findUnique({ where: { code: categoryCode } }),
    db.size.findMany(),
  ]);
  if (!category)
    throw new AppError(400, "VALIDATION_ERROR", "Categoría inexistente.");
  const vatRate = vatRateCode
    ? await db.vatRate.findUnique({ where: { code: vatRateCode } })
    : await db.vatRate.findFirst({ where: { isDefault: true } });
  if (!vatRate) {
    throw new AppError(
      422,
      "INVALID_VAT_RATE",
      "La tarifa de IVA indicada no existe.",
      [{ vatRateCode: vatRateCode ?? null }],
    );
  }
  return {
    category,
    vatRate,
    sizesByCode: Object.fromEntries(sizes.map((s) => [s.code, s])),
  };
}

export async function create(user, body) {
  const id = await prisma.$transaction(async (tx) => {
    const { category, vatRate, sizesByCode } = await resolveRefs(tx, body);
    const values = assertSizeValues(body.sizeValues, sizesByCode);
    if (await tx.ingredient.findUnique({ where: { code: body.code } }))
      throw codeExists();
    try {
      const row = await tx.ingredient.create({
        data: {
          code: body.code,
          name: body.name,
          categoryId: category.id,
          vatRateId: vatRate.id,
          active: body.active ?? true,
          stock: body.stock ?? 0,
          sizeValues: { create: values },
        },
      });
      return row.id;
    } catch (err) {
      if (err?.code === "P2002") throw codeExists();
      throw err;
    }
  });
  return view(prisma, id, user);
}

export async function update(user, id, body) {
  await prisma.$transaction(async (tx) => {
    const current = await tx.ingredient.findUnique({
      where: { id },
      include: { category: true },
    });
    if (!current) throw notFound("Ingrediente no encontrado.");
    const { category, vatRate, sizesByCode } = await resolveRefs(tx, body);
    const values = assertSizeValues(body.sizeValues, sizesByCode);

    if (componentOf(current.category.code) !== componentOf(category.code)) {
      const used = await tx.presetPizzaIngredient.findMany({
        where: { ingredientId: id },
        include: { presetPizza: { select: { name: true } } },
      });
      if (used.length) {
        throw new AppError(
          422,
          "INGREDIENT_CATEGORY_LOCKED",
          "No se puede cambiar la categoría: el ingrediente se usa en recetas y dejaría de cumplirlas.",
          [{ presetPizzas: [...new Set(used.map((u) => u.presetPizza.name))] }],
        );
      }
    }
    if (
      body.code !== current.code &&
      (await tx.ingredient.findUnique({ where: { code: body.code } }))
    ) {
      throw codeExists();
    }
    try {
      // Siempre se actualiza la fila del ingrediente: toma el bloqueo de fila y serializa con las confirmaciones de pedido.
      await tx.ingredient.update({
        where: { id },
        data: {
          code: body.code,
          name: body.name,
          categoryId: category.id,
          vatRateId: vatRate.id,
        },
      });
    } catch (err) {
      if (err?.code === "P2002") throw codeExists();
      throw err;
    }
    for (const v of values) {
      await tx.ingredientSizeValue.upsert({
        where: { ingredientId_sizeId: { ingredientId: id, sizeId: v.sizeId } },
        create: { ingredientId: id, ...v },
        update: { price: v.price, calories: v.calories },
      });
    }
  });
  return view(prisma, id, user);
}

export async function updateStock(user, id, { operation, value }) {
  if (operation === "SET") {
    const r = await prisma.ingredient.updateMany({
      where: { id },
      data: { stock: value },
    });
    if (r.count === 0) throw notFound("Ingrediente no encontrado.");
  } else {
    // Ajuste atómico stock = stock + value, respetando CHECK stock >= 0 (no pisa descuentos concurrentes).
    const where = value < 0 ? { id, stock: { gte: -value } } : { id };
    const r = await prisma.ingredient.updateMany({
      where,
      data: { stock: { increment: value } },
    });
    if (r.count === 0) {
      const exists = await prisma.ingredient.findUnique({
        where: { id },
        select: { stock: true },
      });
      if (!exists) throw notFound("Ingrediente no encontrado.");
      throw new AppError(
        422,
        "STOCK_WOULD_BE_NEGATIVE",
        `El ajuste dejaría el stock en negativo (stock actual: ${exists.stock}).`,
        [{ stock: exists.stock, adjustment: value }],
      );
    }
  }
  return view(prisma, id, user);
}

export async function setActive(user, id, active) {
  const row = await prisma.ingredient.findUnique({
    where: { id },
    include: { _count: { select: { sizeValues: true } } },
  });
  if (!row) throw notFound("Ingrediente no encontrado.");
  if (active && row._count.sizeValues !== SIZE_CODES.length) {
    throw new AppError(
      422,
      "MISSING_SIZE_VALUES",
      "No se puede activar: faltan precio y calorías de algún tamaño.",
      [{ missing: [] }],
    );
  }
  await prisma.ingredient.update({ where: { id }, data: { active } });
  return view(prisma, id, user);
}

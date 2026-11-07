// Fase 6 (QA): completa la cobertura de servicios (catálogo, salud, cotización, ingredientes y
// predefinidas) con un doble de Prisma. Sin base de datos.
import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../src/lib/prisma.js", () => {
  const fn = () => vi.fn();
  const api = {
    $queryRaw: fn(),
    size: { findMany: fn() },
    ingredientCategory: { findMany: fn(), findUnique: fn() },
    vatRate: { findMany: fn(), findUnique: fn(), findFirst: fn() },
    ingredient: {
      findUnique: fn(),
      findMany: fn(),
      count: fn(),
      update: fn(),
      updateMany: fn(),
      create: fn(),
    },
    ingredientSizeValue: { upsert: fn() },
    presetPizza: {
      findUnique: fn(),
      findFirst: fn(),
      findMany: fn(),
      create: fn(),
      update: fn(),
      updateMany: fn(),
    },
    presetPizzaIngredient: {
      findMany: fn(),
      deleteMany: fn(),
      createMany: fn(),
    },
  };
  api.$transaction = async (callback) => callback(api);
  return { prisma: api };
});

import { prisma } from "../../src/lib/prisma.js";
import * as catalogService from "../../src/services/catalog.service.js";
import * as healthService from "../../src/services/health.service.js";
import * as quoteService from "../../src/services/quote.service.js";
import * as ingredientService from "../../src/services/ingredient.service.js";
import * as presetService from "../../src/services/presetPizza.service.js";
import { ING, PRESET_MARGHERITA, uid } from "../helpers/catalog.js";
import { ingredientRow } from "../helpers/fakeDb.js";

const ADMIN = { id: uid(9001), role: "ADMIN" };
const CLIENT = { id: uid(9002), role: "CLIENT" };
const SIZES = [
  { id: 1, code: "INDIVIDUAL", name: "Individual" },
  { id: 2, code: "MEDIUM", name: "Mediana" },
  { id: 3, code: "FAMILY", name: "Familiar" },
];
const withDates = (row) => ({
  ...row,
  createdAt: new Date(),
  updatedAt: new Date(),
});
const rejection = async (p) => {
  try {
    await p;
  } catch (e) {
    return e;
  }
  throw new Error("Se esperaba un rechazo");
};

beforeEach(() => vi.resetAllMocks());

describe("QA-20 / catalog.service y health.service (US-16, US-18, US-23)", () => {
  it("listSizes / listCategories / listVatRates mapean y formatean la tarifa con 2 decimales", async () => {
    prisma.size.findMany.mockResolvedValue(
      SIZES.map((s, i) => ({ ...s, sortOrder: i + 1, extra: "x" })),
    );
    expect(await catalogService.listSizes()).toEqual([
      { code: "INDIVIDUAL", name: "Individual", sortOrder: 1 },
      { code: "MEDIUM", name: "Mediana", sortOrder: 2 },
      { code: "FAMILY", name: "Familiar", sortOrder: 3 },
    ]);
    prisma.ingredientCategory.findMany.mockResolvedValue([
      { code: "DOUGH", name: "Masa", sortOrder: 1 },
    ]);
    expect(await catalogService.listCategories()).toEqual([
      { code: "DOUGH", name: "Masa", sortOrder: 1 },
    ]);
    prisma.vatRate.findMany.mockResolvedValue([
      { code: "VAT_15", name: "IVA 15 %", ratePercent: 15, isDefault: true },
      { code: "VAT_0", name: "IVA 0 %", ratePercent: "0", isDefault: false },
    ]);
    const vat = await catalogService.listVatRates();
    expect(vat.map((v) => [v.code, v.ratePercent, v.isDefault])).toEqual([
      ["VAT_15", "15.00", true],
      ["VAT_0", "0.00", false],
    ]);
  });

  it("health: base disponible -> ok con versión y hora; base caída -> 503 SERVICE_UNAVAILABLE", async () => {
    prisma.$queryRaw.mockResolvedValue([{ "?column?": 1 }]);
    const ok = await healthService.checkHealth();
    expect(ok).toMatchObject({ status: "ok", database: "ok" });
    expect(ok.version).toMatch(/^\d+\.\d+\.\d+/);
    expect(new Date(ok.time).toString()).not.toBe("Invalid Date");
    prisma.$queryRaw.mockRejectedValue(new Error("connection refused"));
    const err = await rejection(healthService.checkHealth());
    expect(err).toMatchObject({ status: 503, code: "SERVICE_UNAVAILABLE" });
    expect(err.message).not.toContain("connection refused");
  });
});

describe("QA-21 / quote.service (US-07, RF-13): cotización sin escritura", () => {
  const arrange = () => {
    prisma.size.findMany.mockResolvedValue(SIZES);
    prisma.presetPizza.findMany.mockResolvedValue([]);
    prisma.ingredient.findMany.mockResolvedValue(
      [ING.dough, ING.sauce, ING.cheese].map(ingredientRow),
    );
  };
  const item = {
    type: "CUSTOM",
    sizeCode: "MEDIUM",
    doughId: ING.dough.id,
    sauceId: ING.sauce.id,
    toppings: [{ ingredientId: ING.cheese.id, portions: 3 }],
    quantity: 1,
  };

  it("US-07: MEDIUM masa 2.00 + salsa 1.00 + queso 1.50 x3 = 7.50 (cálculo parcial con violación de mínimo)", async () => {
    arrange();
    const q = await quoteService.quote([item]);
    expect(q.items[0]).toMatchObject({ unitPrice: "7.50", unitCalories: 690 });
    expect(q.valid).toBe(false);
    expect(q.items[0].violations[0].code).toBe("MIN_TOPPINGS_NOT_MET");
    expect(Object.keys(q).sort()).toEqual(
      ["items", "stock", "totals", "valid", "violations"].sort(),
    );
  });

  it("no escribe: ninguna operación de escritura de Prisma es llamada", async () => {
    arrange();
    await quoteService.quote([item]);
    for (const m of [
      prisma.ingredient.update,
      prisma.ingredient.updateMany,
      prisma.ingredient.create,
      prisma.presetPizza.create,
    ])
      expect(m).not.toHaveBeenCalled();
    expect(prisma.$queryRaw).not.toHaveBeenCalled(); // sin SELECT ... FOR UPDATE ni secuencias
  });
});

describe("QA-22 / ingredient.service: listado, filtros, edición y estado (US-15, US-16, US-17)", () => {
  it("cliente: solo activos (where.active = true) aunque pida includeInactive; sin page devuelve lista completa", async () => {
    prisma.ingredient.findMany.mockResolvedValue([
      withDates(ingredientRow(ING.cheese)),
    ]);
    const res = await ingredientService.list(CLIENT, { includeInactive: true });
    expect(prisma.ingredient.findMany.mock.calls[0][0].where).toEqual({
      active: true,
    });
    expect(res).not.toHaveProperty("page");
    expect(res.data[0]).not.toHaveProperty("createdAt");
  });

  it("admin con includeInactive=true no filtra por activo; sin él, sí", async () => {
    prisma.ingredient.findMany.mockResolvedValue([]);
    await ingredientService.list(ADMIN, { includeInactive: true });
    expect(prisma.ingredient.findMany.mock.calls[0][0].where).toEqual({});
    await ingredientService.list(ADMIN, {});
    expect(prisma.ingredient.findMany.mock.calls[1][0].where).toEqual({
      active: true,
    });
  });

  it("filtros de categoría y búsqueda; paginación con total, skip y take", async () => {
    prisma.ingredient.count.mockResolvedValue(45);
    prisma.ingredient.findMany.mockResolvedValue([]);
    const res = await ingredientService.list(ADMIN, {
      category: "CHEESE",
      search: "moz",
      page: 3,
      pageSize: 10,
    });
    const args = prisma.ingredient.findMany.mock.calls[0][0];
    expect(args).toMatchObject({ skip: 20, take: 10 });
    expect(args.where.category).toEqual({ code: "CHEESE" });
    expect(args.where.OR).toHaveLength(2);
    expect(res).toMatchObject({ page: 3, pageSize: 10, total: 45 });
  });

  it("update: cambiar la categoría (masa -> queso) de un ingrediente usado en recetas -> 422 INGREDIENT_CATEGORY_LOCKED", async () => {
    prisma.ingredient.findUnique.mockResolvedValue({
      id: ING.dough.id,
      code: "MAS-TRA",
      category: { code: "DOUGH" },
    });
    prisma.ingredientCategory.findUnique.mockResolvedValue({
      id: 3,
      code: "CHEESE",
    });
    prisma.size.findMany.mockResolvedValue(SIZES);
    prisma.vatRate.findFirst.mockResolvedValue({ id: 1 });
    prisma.presetPizzaIngredient.findMany.mockResolvedValue([
      { presetPizza: { name: "Margarita" } },
      { presetPizza: { name: "Margarita" } },
    ]);
    const sv = (sizeCode) => ({ sizeCode, price: "1.00", calories: 1 });
    const err = await rejection(
      ingredientService.update(ADMIN, ING.dough.id, {
        code: "MAS-TRA",
        name: "Masa",
        categoryCode: "CHEESE",
        sizeValues: [sv("INDIVIDUAL"), sv("MEDIUM"), sv("FAMILY")],
      }),
    );
    expect(err).toMatchObject({
      status: 422,
      code: "INGREDIENT_CATEGORY_LOCKED",
    });
    expect(err.details[0].presetPizzas).toEqual(["Margarita"]);
    expect(prisma.ingredient.update).not.toHaveBeenCalled();
  });

  it("update correcto: guarda los 3 tamaños de forma independiente (upsert por tamaño) y devuelve la vista", async () => {
    prisma.ingredient.findUnique
      .mockResolvedValueOnce({
        id: ING.cheese.id,
        code: "QUE-MOZ",
        category: { code: "CHEESE" },
      })
      .mockResolvedValue(withDates(ingredientRow(ING.cheese)));
    prisma.ingredientCategory.findUnique.mockResolvedValue({
      id: 3,
      code: "CHEESE",
    });
    prisma.size.findMany.mockResolvedValue(SIZES);
    prisma.vatRate.findUnique.mockResolvedValue({ id: 2, code: "VAT_0" });
    prisma.ingredient.update.mockResolvedValue({});
    const view = await ingredientService.update(ADMIN, ING.cheese.id, {
      code: "QUE-MOZ",
      name: "Queso mozzarella",
      categoryCode: "CHEESE",
      vatRateCode: "VAT_0",
      sizeValues: [
        { sizeCode: "INDIVIDUAL", price: "1.10", calories: 81 },
        { sizeCode: "MEDIUM", price: "1.60", calories: 111 },
        { sizeCode: "FAMILY", price: "2.30", calories: 161 },
      ],
    });
    expect(prisma.ingredientSizeValue.upsert).toHaveBeenCalledTimes(3);
    const updates = prisma.ingredientSizeValue.upsert.mock.calls.map(
      (c) => c[0].update,
    );
    expect(updates).toEqual([
      { price: "1.10", calories: 81 },
      { price: "1.60", calories: 111 },
      { price: "2.30", calories: 161 },
    ]);
    expect(prisma.ingredient.update.mock.calls[0][0].data.vatRateId).toBe(2);
    expect(view.code).toBe("QUE-MOZ");
  });

  it("update: ingrediente inexistente -> 404; nuevo código ya usado por otro -> 409", async () => {
    prisma.ingredient.findUnique.mockResolvedValue(null);
    const body = {
      code: "X",
      name: "Xx",
      categoryCode: "CHEESE",
      sizeValues: [],
    };
    expect(
      (await rejection(ingredientService.update(ADMIN, uid(1), body))).code,
    ).toBe("NOT_FOUND");
    prisma.ingredient.findUnique
      .mockResolvedValueOnce({
        id: ING.cheese.id,
        code: "QUE-MOZ",
        category: { code: "CHEESE" },
      })
      .mockResolvedValueOnce({ id: "otro" });
    prisma.ingredientCategory.findUnique.mockResolvedValue({
      id: 3,
      code: "CHEESE",
    });
    prisma.size.findMany.mockResolvedValue(SIZES);
    prisma.vatRate.findFirst.mockResolvedValue({ id: 1 });
    const sv = (sizeCode) => ({ sizeCode, price: "1.00", calories: 1 });
    const dup = await rejection(
      ingredientService.update(ADMIN, ING.cheese.id, {
        code: "QUE-OTRO",
        name: "Queso",
        categoryCode: "CHEESE",
        sizeValues: [sv("INDIVIDUAL"), sv("MEDIUM"), sv("FAMILY")],
      }),
    );
    expect(dup).toMatchObject({ status: 409, code: "INGREDIENT_CODE_EXISTS" });
  });

  it("create: P2002 de la BD (carrera entre dos altas) se traduce a 409 INGREDIENT_CODE_EXISTS", async () => {
    prisma.ingredientCategory.findUnique.mockResolvedValue({ id: 3 });
    prisma.size.findMany.mockResolvedValue(SIZES);
    prisma.vatRate.findFirst.mockResolvedValue({ id: 1 });
    prisma.ingredient.findUnique.mockResolvedValue(null);
    prisma.ingredient.create.mockRejectedValue(
      Object.assign(new Error("dup"), { code: "P2002" }),
    );
    const sv = (sizeCode) => ({ sizeCode, price: "1.00", calories: 1 });
    const err = await rejection(
      ingredientService.create(ADMIN, {
        code: "NUE",
        name: "Nuevo",
        categoryCode: "CHEESE",
        sizeValues: [sv("INDIVIDUAL"), sv("MEDIUM"), sv("FAMILY")],
      }),
    );
    expect(err.code).toBe("INGREDIENT_CODE_EXISTS");
  });

  it("create: IVA por defecto (15 %) y activo/stock por defecto cuando no se indican (US-15)", async () => {
    prisma.ingredientCategory.findUnique.mockResolvedValue({ id: 3 });
    prisma.size.findMany.mockResolvedValue(SIZES);
    prisma.vatRate.findFirst.mockResolvedValue({ id: 7, isDefault: true });
    prisma.ingredient.findUnique
      .mockResolvedValueOnce(null)
      .mockResolvedValue(withDates(ingredientRow(ING.cheese)));
    prisma.ingredient.create.mockResolvedValue({ id: ING.cheese.id });
    const sv = (sizeCode) => ({ sizeCode, price: "1.00", calories: 1 });
    await ingredientService.create(ADMIN, {
      code: "NUE",
      name: "Nuevo",
      categoryCode: "CHEESE",
      sizeValues: [sv("INDIVIDUAL"), sv("MEDIUM"), sv("FAMILY")],
    });
    expect(prisma.vatRate.findFirst).toHaveBeenCalledWith({
      where: { isDefault: true },
    });
    expect(prisma.ingredient.create.mock.calls[0][0].data).toMatchObject({
      vatRateId: 7,
      active: true,
      stock: 0,
    });
  });

  it("categoría inexistente -> 400 VALIDATION_ERROR", async () => {
    prisma.ingredientCategory.findUnique.mockResolvedValue(null);
    prisma.size.findMany.mockResolvedValue(SIZES);
    const err = await rejection(
      ingredientService.create(ADMIN, {
        code: "N",
        name: "Nn",
        categoryCode: "NOPE",
        sizeValues: [],
      }),
    );
    expect(err).toMatchObject({ status: 400, code: "VALIDATION_ERROR" });
  });

  it("stock SET: actualiza y devuelve la vista; ingrediente inexistente -> 404", async () => {
    prisma.ingredient.updateMany.mockResolvedValue({ count: 1 });
    prisma.ingredient.findUnique.mockResolvedValue(
      withDates(ingredientRow(ING.cheese)),
    );
    await ingredientService.updateStock(ADMIN, ING.cheese.id, {
      operation: "SET",
      value: 0,
    });
    expect(prisma.ingredient.updateMany).toHaveBeenCalledWith({
      where: { id: ING.cheese.id },
      data: { stock: 0 },
    });
    prisma.ingredient.updateMany.mockResolvedValue({ count: 0 });
    expect(
      (
        await rejection(
          ingredientService.updateStock(ADMIN, uid(5), {
            operation: "SET",
            value: 5,
          }),
        )
      ).code,
    ).toBe("NOT_FOUND");
  });

  it("setActive: desactivar conserva la fila (update active=false, sin borrado); inexistente -> 404; activar con 3 tamaños funciona", async () => {
    prisma.ingredient.findUnique
      .mockResolvedValueOnce({ id: ING.cheese.id, _count: { sizeValues: 3 } })
      .mockResolvedValue(
        withDates({ ...ingredientRow(ING.cheese), active: false }),
      );
    prisma.ingredient.update.mockResolvedValue({});
    const view = await ingredientService.setActive(ADMIN, ING.cheese.id, false);
    expect(prisma.ingredient.update).toHaveBeenCalledWith({
      where: { id: ING.cheese.id },
      data: { active: false },
    });
    expect(view.active).toBe(false);
    prisma.ingredient.findUnique.mockReset();
    prisma.ingredient.findUnique.mockResolvedValueOnce(null);
    expect(
      (await rejection(ingredientService.setActive(ADMIN, uid(5), true))).code,
    ).toBe("NOT_FOUND");
    prisma.ingredient.findUnique
      .mockResolvedValueOnce({ id: ING.cheese.id, _count: { sizeValues: 3 } })
      .mockResolvedValue(withDates(ingredientRow(ING.cheese)));
    expect(
      (await ingredientService.setActive(ADMIN, ING.cheese.id, true)).active,
    ).toBe(true);
  });
});

describe("QA-23 / presetPizza.service: vistas calculadas, disponibilidad y edición (US-03, US-19)", () => {
  const presetRow = (overrides = {}) => ({
    id: PRESET_MARGHERITA.id,
    code: "MARGHERITA",
    name: "Margarita",
    description: null,
    active: true,
    sortOrder: 1,
    ingredients: PRESET_MARGHERITA.recipe.map((r) => ({
      ingredientId: r.ingredientId,
      portions: r.portions,
      ingredient: ingredientRow(
        [ING.dough, ING.sauce, ING.cheese].find((i) => i.id === r.ingredientId),
      ),
    })),
    ...overrides,
  });

  it("US-03: la lista calcula precio y calorías por tamaño con la fórmula (sin precio fijo) y marca disponible", async () => {
    prisma.presetPizza.findMany.mockResolvedValue([presetRow()]);
    prisma.size.findMany.mockResolvedValue(SIZES);
    const [view] = await presetService.list(CLIENT, {});
    expect(view.pricesBySize).toEqual([
      { sizeCode: "INDIVIDUAL", price: "4.10", calories: 370 },
      { sizeCode: "MEDIUM", price: "6.00", calories: 580 },
      { sizeCode: "FAMILY", price: "8.90", calories: 860 },
    ]);
    expect(view).toMatchObject({ available: true, unavailableReasons: [] });
    expect(view.recipe.map((r) => r.categoryCode)).toEqual([
      "DOUGH",
      "SAUCE",
      "CHEESE",
    ]);
    expect(prisma.presetPizza.findMany.mock.calls[0][0].where).toEqual({
      active: true,
    });
    expect(view).not.toHaveProperty("price");
  });

  it("US-03/S-25: con un ingrediente de la receta sin stock la predefinida sale no disponible con el motivo", async () => {
    const row = presetRow();
    row.ingredients[2].ingredient.stock = 1; // la receta pide 2 porciones de queso
    prisma.presetPizza.findMany.mockResolvedValue([row]);
    prisma.size.findMany.mockResolvedValue(SIZES);
    const [view] = await presetService.list(ADMIN, { includeInactive: true });
    expect(prisma.presetPizza.findMany.mock.calls[0][0].where).toEqual({});
    expect(view.available).toBe(false);
    expect(view.unavailableReasons[0].meta.reason).toBe("OUT_OF_STOCK");
  });

  it("cliente: una predefinida desactivada responde 404; el admin la ve", async () => {
    prisma.presetPizza.findUnique.mockResolvedValue(
      presetRow({ active: false }),
    );
    prisma.size.findMany.mockResolvedValue(SIZES);
    expect(
      (await rejection(presetService.getById(CLIENT, PRESET_MARGHERITA.id)))
        .code,
    ).toBe("NOT_FOUND");
    expect(
      (await presetService.getById(ADMIN, PRESET_MARGHERITA.id)).active,
    ).toBe(false);
    prisma.presetPizza.findUnique.mockResolvedValue(null);
    expect((await rejection(presetService.getById(ADMIN, uid(1)))).code).toBe(
      "NOT_FOUND",
    );
  });

  it("US-19: editar reemplaza la receta en una transacción (deleteMany + createMany) y no toca pedidos", async () => {
    prisma.presetPizza.findUnique.mockImplementation(async ({ select }) =>
      select ? { id: PRESET_MARGHERITA.id } : presetRow(),
    );
    prisma.ingredient.findMany.mockResolvedValue(
      [ING.dough, ING.sauce, ING.cheese, ING.ham].map(ingredientRow),
    );
    prisma.presetPizza.findFirst.mockResolvedValue(null);
    prisma.size.findMany.mockResolvedValue(SIZES);
    await presetService.update(PRESET_MARGHERITA.id, {
      code: "MARGHERITA",
      name: "Margarita",
      recipe: [
        { ingredientId: ING.dough.id, portions: 1 },
        { ingredientId: ING.sauce.id, portions: 1 },
        { ingredientId: ING.ham.id, portions: 3 },
      ],
    });
    expect(prisma.presetPizzaIngredient.deleteMany).toHaveBeenCalledWith({
      where: { presetPizzaId: PRESET_MARGHERITA.id },
    });
    expect(
      prisma.presetPizzaIngredient.createMany.mock.calls[0][0].data,
    ).toHaveLength(3);
    expect(
      prisma.presetPizzaIngredient.createMany.mock.calls[0][0].data[2].portions,
    ).toBe(3);
  });

  it("US-19: receta con 4 porciones de un ingrediente -> 422 INVALID_RECIPE; con una sola línea de topping se acepta", async () => {
    prisma.presetPizza.findUnique.mockResolvedValue({
      id: PRESET_MARGHERITA.id,
    });
    prisma.ingredient.findMany.mockResolvedValue(
      [ING.dough, ING.sauce, ING.cheese].map(ingredientRow),
    );
    const err = await rejection(
      presetService.update(PRESET_MARGHERITA.id, {
        code: "M",
        name: "M",
        recipe: [
          { ingredientId: ING.dough.id, portions: 1 },
          { ingredientId: ING.sauce.id, portions: 1 },
          { ingredientId: ING.cheese.id, portions: 4 },
        ],
      }),
    );
    expect(err).toMatchObject({ status: 422, code: "INVALID_RECIPE" });
    expect(err.details[0].code).toBe("MAX_PORTIONS_EXCEEDED");
    expect(prisma.presetPizzaIngredient.deleteMany).not.toHaveBeenCalled();
  });

  it("P2002 en update/create se traduce a 409 por nombre o por código", async () => {
    prisma.presetPizza.findUnique.mockImplementation(async ({ select }) =>
      select ? { id: PRESET_MARGHERITA.id } : presetRow(),
    );
    prisma.ingredient.findMany.mockResolvedValue(
      [ING.dough, ING.sauce].map(ingredientRow),
    );
    prisma.presetPizza.findFirst.mockResolvedValue(null);
    prisma.presetPizza.update.mockRejectedValue(
      Object.assign(new Error("dup"), {
        code: "P2002",
        meta: { target: ["name"] },
      }),
    );
    const body = {
      code: "M",
      name: "M",
      recipe: [
        { ingredientId: ING.dough.id, portions: 1 },
        { ingredientId: ING.sauce.id, portions: 1 },
      ],
    };
    expect(
      (await rejection(presetService.update(PRESET_MARGHERITA.id, body))).code,
    ).toBe("PRESET_NAME_EXISTS");
    prisma.presetPizza.update.mockRejectedValue(
      Object.assign(new Error("dup"), {
        code: "P2002",
        meta: { target: ["code"] },
      }),
    );
    expect(
      (await rejection(presetService.update(PRESET_MARGHERITA.id, body))).code,
    ).toBe("PRESET_CODE_EXISTS");
    prisma.presetPizza.update.mockRejectedValue(new Error("otro error"));
    expect(
      (await rejection(presetService.update(PRESET_MARGHERITA.id, body)))
        .message,
    ).toBe("otro error");
  });

  it("setActive: baja lógica (no hay borrado); inexistente -> 404", async () => {
    prisma.presetPizza.updateMany.mockResolvedValue({ count: 1 });
    prisma.presetPizza.findUnique.mockResolvedValue(
      presetRow({ active: false }),
    );
    prisma.size.findMany.mockResolvedValue(SIZES);
    expect(
      (await presetService.setActive(PRESET_MARGHERITA.id, false)).active,
    ).toBe(false);
    expect(prisma.presetPizza.updateMany).toHaveBeenCalledWith({
      where: { id: PRESET_MARGHERITA.id },
      data: { active: false },
    });
    prisma.presetPizza.updateMany.mockResolvedValue({ count: 0 });
    expect((await rejection(presetService.setActive(uid(1), true))).code).toBe(
      "NOT_FOUND",
    );
  });
});

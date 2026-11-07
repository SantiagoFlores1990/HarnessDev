import { beforeEach, describe, expect, it, vi } from "vitest";

// Doble mínimo de Prisma con funciones espía para ingredient.service y presetPizza.service.
vi.mock("../../src/lib/prisma.js", () => {
  const fn = () => vi.fn();
  const api = {
    ingredient: {
      findUnique: fn(),
      findMany: fn(),
      updateMany: fn(),
      update: fn(),
      create: fn(),
      count: fn(),
    },
    ingredientCategory: { findUnique: fn() },
    ingredientSizeValue: { upsert: fn() },
    presetPizza: {
      findUnique: fn(),
      findFirst: fn(),
      create: fn(),
      findMany: fn(),
    },
    presetPizzaIngredient: { findMany: fn() },
    vatRate: { findUnique: fn(), findFirst: fn() },
    size: { findMany: fn() },
  };
  api.$transaction = async (callback) => callback(api);
  return { prisma: api };
});

import { prisma } from "../../src/lib/prisma.js";
import * as ingredientService from "../../src/services/ingredient.service.js";
import * as presetService from "../../src/services/presetPizza.service.js";
import { ING, uid } from "../helpers/catalog.js";
import { ingredientRow } from "../helpers/fakeDb.js";

const ADMIN = { id: uid(9001), role: "ADMIN" };
const rejection = async (p) => {
  try {
    await p;
  } catch (e) {
    return e;
  }
  throw new Error("Se esperaba un rechazo");
};
const withDates = (row) => ({
  ...row,
  createdAt: new Date(),
  updatedAt: new Date(),
});

beforeEach(() => vi.resetAllMocks());

describe("ingredient.service", () => {
  it("ADD negativo que dejaría stock < 0 -> 422 STOCK_WOULD_BE_NEGATIVE (actualización condicionada, atómica)", async () => {
    prisma.ingredient.updateMany.mockResolvedValue({ count: 0 });
    prisma.ingredient.findUnique.mockResolvedValue({ stock: 3 });
    const err = await rejection(
      ingredientService.updateStock(ADMIN, ING.cheese.id, {
        operation: "ADD",
        value: -5,
      }),
    );
    expect(err).toMatchObject({ status: 422, code: "STOCK_WOULD_BE_NEGATIVE" });
    expect(prisma.ingredient.updateMany).toHaveBeenCalledWith({
      where: { id: ING.cheese.id, stock: { gte: 5 } },
      data: { stock: { increment: -5 } },
    });
  });
  it("ADD sobre un ingrediente inexistente -> 404", async () => {
    prisma.ingredient.updateMany.mockResolvedValue({ count: 0 });
    prisma.ingredient.findUnique.mockResolvedValue(null);
    const err = await rejection(
      ingredientService.updateStock(ADMIN, uid(1), {
        operation: "ADD",
        value: -1,
      }),
    );
    expect(err.code).toBe("NOT_FOUND");
  });
  it("ADD positivo usa increment atómico (sin leer-modificar-escribir)", async () => {
    prisma.ingredient.updateMany.mockResolvedValue({ count: 1 });
    prisma.ingredient.findUnique.mockResolvedValue(
      withDates(ingredientRow(ING.cheese)),
    );
    const view = await ingredientService.updateStock(ADMIN, ING.cheese.id, {
      operation: "ADD",
      value: 10,
    });
    expect(prisma.ingredient.updateMany).toHaveBeenCalledWith({
      where: { id: ING.cheese.id },
      data: { stock: { increment: 10 } },
    });
    expect(view).toMatchObject({ code: "QUE-MOZ", stock: 100 });
  });
  it("vista de cliente: incluye stock y omite createdAt/updatedAt; la de admin los incluye", async () => {
    prisma.ingredient.findUnique.mockResolvedValue(
      withDates(ingredientRow(ING.cheese)),
    );
    const clientView = await ingredientService.getById(
      { id: uid(9002), role: "CLIENT" },
      ING.cheese.id,
    );
    expect(clientView).toHaveProperty("stock");
    expect(clientView).not.toHaveProperty("createdAt");
    const adminView = await ingredientService.getById(ADMIN, ING.cheese.id);
    expect(adminView).toHaveProperty("createdAt");
    expect(adminView.sizeValues.map((s) => s.sizeCode)).toEqual([
      "INDIVIDUAL",
      "MEDIUM",
      "FAMILY",
    ]);
    expect(adminView.sizeValues[1]).toEqual({
      sizeCode: "MEDIUM",
      price: "1.50",
      calories: 110,
    });
    expect(adminView.vatRate).toEqual({ code: "VAT_15", ratePercent: "15.00" });
  });
  it("cliente: un ingrediente inactivo responde 404", async () => {
    prisma.ingredient.findUnique.mockResolvedValue(
      withDates({ ...ingredientRow(ING.cheese), active: false }),
    );
    const err = await rejection(
      ingredientService.getById(
        { id: uid(9002), role: "CLIENT" },
        ING.cheese.id,
      ),
    );
    expect(err.code).toBe("NOT_FOUND");
  });
  it("crear con tamaños faltantes o repetidos -> 422 MISSING_SIZE_VALUES con el detalle", async () => {
    prisma.ingredientCategory.findUnique.mockResolvedValue({
      id: 1,
      code: "OTHER",
    });
    prisma.size.findMany.mockResolvedValue([
      { id: 1, code: "INDIVIDUAL" },
      { id: 2, code: "MEDIUM" },
      { id: 3, code: "FAMILY" },
    ]);
    prisma.vatRate.findFirst.mockResolvedValue({ id: 1, code: "VAT_15" });
    const sv = (sizeCode) => ({ sizeCode, price: "1.00", calories: 1 });
    const body = { code: "NUE-1", name: "Nuevo", categoryCode: "OTHER" };
    const missing = await rejection(
      ingredientService.create(ADMIN, {
        ...body,
        sizeValues: [sv("INDIVIDUAL")],
      }),
    );
    expect(missing).toMatchObject({ status: 422, code: "MISSING_SIZE_VALUES" });
    expect(missing.details[0].missing).toEqual(["MEDIUM", "FAMILY"]);
    const dup = await rejection(
      ingredientService.create(ADMIN, {
        ...body,
        sizeValues: [
          sv("INDIVIDUAL"),
          sv("INDIVIDUAL"),
          sv("MEDIUM"),
          sv("FAMILY"),
        ],
      }),
    );
    expect(dup.details[0].duplicated).toEqual(["INDIVIDUAL"]);
    expect(prisma.ingredient.create).not.toHaveBeenCalled();
  });
  it("tarifa de IVA inexistente -> 422 INVALID_VAT_RATE", async () => {
    prisma.ingredientCategory.findUnique.mockResolvedValue({ id: 1 });
    prisma.size.findMany.mockResolvedValue([]);
    prisma.vatRate.findUnique.mockResolvedValue(null);
    const err = await rejection(
      ingredientService.create(ADMIN, {
        code: "X-1",
        name: "Xx",
        categoryCode: "OTHER",
        vatRateCode: "VAT_99",
        sizeValues: [],
      }),
    );
    expect(err).toMatchObject({ status: 422, code: "INVALID_VAT_RATE" });
  });
  it("código repetido -> 409 INGREDIENT_CODE_EXISTS", async () => {
    prisma.ingredientCategory.findUnique.mockResolvedValue({ id: 1 });
    prisma.size.findMany.mockResolvedValue([
      { id: 1, code: "INDIVIDUAL" },
      { id: 2, code: "MEDIUM" },
      { id: 3, code: "FAMILY" },
    ]);
    prisma.vatRate.findFirst.mockResolvedValue({ id: 1 });
    prisma.ingredient.findUnique.mockResolvedValue({ id: "existente" });
    const sv = (sizeCode) => ({ sizeCode, price: "1.00", calories: 1 });
    const err = await rejection(
      ingredientService.create(ADMIN, {
        code: "DUP",
        name: "Dup",
        categoryCode: "OTHER",
        sizeValues: [sv("INDIVIDUAL"), sv("MEDIUM"), sv("FAMILY")],
      }),
    );
    expect(err.code).toBe("INGREDIENT_CODE_EXISTS");
  });
  it("activar un ingrediente sin los 3 tamaños -> 422 MISSING_SIZE_VALUES", async () => {
    prisma.ingredient.findUnique.mockResolvedValue({
      id: ING.cheese.id,
      _count: { sizeValues: 2 },
    });
    const err = await rejection(
      ingredientService.setActive(ADMIN, ING.cheese.id, true),
    );
    expect(err.code).toBe("MISSING_SIZE_VALUES");
    expect(prisma.ingredient.update).not.toHaveBeenCalled();
  });
});

describe("presetPizza.service: validación de receta (INVALID_RECIPE)", () => {
  const recipeRows = [ING.dough, ING.sauce, ING.cheese].map(ingredientRow);
  const body = (recipe) => ({ code: "NUEVA", name: "Nueva", recipe });

  it("receta sin masa o con porciones fuera de regla -> 422 INVALID_RECIPE con violaciones", async () => {
    prisma.ingredient.findMany.mockResolvedValue(recipeRows);
    const err = await rejection(
      presetService.create(
        body([
          { ingredientId: ING.sauce.id, portions: 1 },
          { ingredientId: ING.cheese.id, portions: 1 },
        ]),
      ),
    );
    expect(err).toMatchObject({ status: 422, code: "INVALID_RECIPE" });
    expect(err.details.map((d) => d.code)).toEqual(["DOUGH_REQUIRED"]);
    expect(prisma.presetPizza.create).not.toHaveBeenCalled();
  });
  it("receta válida con un solo topping (sin mínimo de toppings) se crea", async () => {
    prisma.ingredient.findMany.mockResolvedValue(recipeRows);
    prisma.presetPizza.findFirst.mockResolvedValue(null);
    prisma.presetPizza.create.mockResolvedValue({ id: uid(300) });
    prisma.presetPizza.findUnique.mockResolvedValue(null); // viewById devuelve null: solo importa que llegó a crear
    await presetService.create(
      body([
        { ingredientId: ING.dough.id, portions: 1 },
        { ingredientId: ING.sauce.id, portions: 1 },
        { ingredientId: ING.cheese.id, portions: 3 },
      ]),
    );
    expect(prisma.presetPizza.create).toHaveBeenCalledTimes(1);
    expect(
      prisma.presetPizza.create.mock.calls[0][0].data.ingredients.create,
    ).toHaveLength(3);
  });
  it("código o nombre repetidos -> 409 PRESET_CODE_EXISTS / PRESET_NAME_EXISTS", async () => {
    prisma.ingredient.findMany.mockResolvedValue(recipeRows);
    const valid = body([
      { ingredientId: ING.dough.id, portions: 1 },
      { ingredientId: ING.sauce.id, portions: 1 },
    ]);
    prisma.presetPizza.findFirst.mockResolvedValueOnce({ id: "x" });
    expect((await rejection(presetService.create(valid))).code).toBe(
      "PRESET_CODE_EXISTS",
    );
    prisma.presetPizza.findFirst
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ id: "x" });
    expect((await rejection(presetService.create(valid))).code).toBe(
      "PRESET_NAME_EXISTS",
    );
  });
  it("editar una predefinida inexistente -> 404", async () => {
    prisma.presetPizza.findUnique.mockResolvedValue(null);
    expect((await rejection(presetService.update(uid(1), body([])))).code).toBe(
      "NOT_FOUND",
    );
  });
});

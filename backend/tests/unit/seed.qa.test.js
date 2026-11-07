// Fase 6 (QA) / US-21, RF-26: valida los DATOS del seed y la generación de contraseñas sin base de
// datos (los datos son constantes exportadas; seedUsers recibe un doble de Prisma).
import { describe, expect, it, vi } from "vitest";
import bcrypt from "bcryptjs";
import {
  SAMPLE_INGREDIENTS,
  SAMPLE_PRESETS,
  seedUsers,
} from "../../prisma/seed-lib.js";
import {
  presetAvailability,
  quoteOrder,
  validateRecipe,
} from "../../src/services/pricing-engine/index.js";

const SIZE_CODES = ["INDIVIDUAL", "MEDIUM", "FAMILY"];

const catalog = () => {
  const ingredients = new Map();
  for (const [
    code,
    name,
    categoryCode,
    vat,
    stock,
    prices,
    kcal,
  ] of SAMPLE_INGREDIENTS) {
    const sizeValues = {};
    SIZE_CODES.forEach((s, i) => {
      sizeValues[s] = { price: prices[i], calories: kcal[i] };
    });
    ingredients.set(code, {
      id: code,
      code,
      name,
      categoryCode,
      active: true,
      stock,
      vatRatePercent: vat === "VAT_0" ? "0.00" : "15.00",
      sizeValues,
    });
  }
  const presets = new Map(
    SAMPLE_PRESETS.map(([code, name, , , recipe]) => [
      code,
      {
        id: code,
        code,
        name,
        active: true,
        recipe: recipe.map(([ingredientId, portions]) => ({
          ingredientId,
          portions,
        })),
      },
    ]),
  );
  return {
    sizes: Object.fromEntries(
      SIZE_CODES.map((c) => [c, { id: c, code: c, name: c }]),
    ),
    ingredients,
    presets,
  };
};

describe("QA-30 / US-21: datos de ejemplo del seed", () => {
  it("hay 20 ingredientes con código único: 3 masas, 3 salsas, quesos, carnes y vegetales", () => {
    expect(SAMPLE_INGREDIENTS).toHaveLength(20);
    const codes = SAMPLE_INGREDIENTS.map((r) => r[0]);
    expect(new Set(codes).size).toBe(20);
    const byCategory = {};
    for (const r of SAMPLE_INGREDIENTS)
      byCategory[r[2]] = (byCategory[r[2]] ?? 0) + 1;
    expect(byCategory).toMatchObject({ DOUGH: 3, SAUCE: 3 });
    expect(byCategory.CHEESE).toBeGreaterThanOrEqual(2);
    expect(byCategory.MEAT).toBeGreaterThanOrEqual(2);
    expect(byCategory.VEGETABLE).toBeGreaterThanOrEqual(2);
  });

  it("la mayoría de ingredientes tiene IVA 15 % y algunos 0 %", () => {
    const v15 = SAMPLE_INGREDIENTS.filter((r) => r[3] === "VAT_15").length;
    const v0 = SAMPLE_INGREDIENTS.filter((r) => r[3] === "VAT_0").length;
    expect(v15 + v0).toBe(20);
    expect(v15).toBeGreaterThan(v0);
    expect(v0).toBeGreaterThan(0);
  });

  it("precio y calorías distintos y crecientes por tamaño (sin factor fijo), stock inicial positivo, precios con 2 decimales", () => {
    for (const [code, , , , stock, prices, kcal] of SAMPLE_INGREDIENTS) {
      expect(stock, code).toBeGreaterThan(0);
      expect(prices, code).toHaveLength(3);
      for (const p of prices) expect(p, code).toMatch(/^\d+\.\d{2}$/);
      expect(Number(prices[0]) < Number(prices[1]), code).toBe(true);
      expect(Number(prices[1]) < Number(prices[2]), code).toBe(true);
      expect(kcal[0] < kcal[1] && kcal[1] < kcal[2], code).toBe(true);
    }
  });

  it("las 5 predefinidas existen por nombre y todas las recetas son válidas (masa y salsa x1, 1..3 porciones)", () => {
    expect(SAMPLE_PRESETS.map((p) => p[1])).toEqual([
      "Margarita",
      "Pepperoni",
      "Hawaiana",
      "Vegetariana",
      "4 Quesos",
    ]);
    const cat = catalog();
    for (const [, preset] of cat.presets) {
      expect(validateRecipe(preset.recipe, cat), preset.name).toEqual([]);
    }
  });

  it("con el stock inicial las 5 predefinidas están disponibles y su precio sale de la fórmula en los 3 tamaños", () => {
    const cat = catalog();
    for (const [, preset] of cat.presets) {
      expect(presetAvailability(preset, cat), preset.name).toEqual([]);
      for (const sizeCode of SIZE_CODES) {
        const r = quoteOrder(
          [
            {
              type: "PRESET",
              presetPizzaId: preset.id,
              sizeCode,
              extras: [],
              quantity: 1,
            },
          ],
          cat,
        );
        expect(r.items[0].valid, `${preset.name} ${sizeCode}`).toBe(true);
        const expected = preset.recipe.reduce(
          (acc, r2) =>
            acc +
            Math.round(
              Number(
                cat.ingredients.get(r2.ingredientId).sizeValues[sizeCode].price,
              ) * 100,
            ) *
              r2.portions,
          0,
        );
        expect(r.items[0].unitPrice).toBe((expected / 100).toFixed(2));
      }
    }
  });
});

describe("QA-31 / US-21, RNF-03: usuarios del seed y contraseñas", () => {
  const fakePrisma = (existing = new Set()) => {
    const created = [];
    return {
      created,
      user: {
        findUnique: vi.fn(async ({ where }) =>
          existing.has(where.email) ? { id: "x" } : null,
        ),
        create: vi.fn(async ({ data }) => {
          created.push(data);
          return data;
        }),
      },
      role: {
        findUnique: vi.fn(async ({ where }) => ({
          id: where.code === "ADMIN" ? 1 : 2,
        })),
      },
    };
  };
  const base = {
    adminEmail: "Admin@GoodPizza.local ",
    clientEmail: "cliente@goodpizza.local",
    cost: 4,
  };

  it("sin SEED_*_PASSWORD genera una contraseña aleatoria distinta por usuario, la devuelve una vez y guarda solo el hash bcrypt", async () => {
    const db = fakePrisma();
    const generated = await seedUsers(db, base);
    expect(generated).toHaveLength(2);
    const [a, c] = generated;
    expect(a.generatedPassword).not.toBe(c.generatedPassword);
    expect(a.generatedPassword.length).toBeGreaterThanOrEqual(12);
    expect(a.email).toBe("admin@goodpizza.local");
    expect(db.created).toHaveLength(2);
    for (const [i, user] of db.created.entries()) {
      expect(user.passwordHash).not.toContain(generated[i].generatedPassword);
      expect(
        await bcrypt.compare(generated[i].generatedPassword, user.passwordHash),
      ).toBe(true);
    }
    expect(db.created.map((u) => u.roleId)).toEqual([1, 2]);
  });

  it("con SEED_*_PASSWORD definidas no genera ni devuelve contraseñas", async () => {
    const db = fakePrisma();
    const generated = await seedUsers(db, {
      ...base,
      adminPassword: "clave-de-prueba-1",
      clientPassword: "clave-de-prueba-2",
    });
    expect(generated).toEqual([]);
    expect(
      await bcrypt.compare("clave-de-prueba-1", db.created[0].passwordHash),
    ).toBe(true);
  });

  it("es idempotente: un usuario existente no se vuelve a crear ni cambia su contraseña", async () => {
    const db = fakePrisma(
      new Set(["admin@goodpizza.local", "cliente@goodpizza.local"]),
    );
    const generated = await seedUsers(db, base);
    expect(generated).toEqual([]);
    expect(db.user.create).not.toHaveBeenCalled();
  });
});

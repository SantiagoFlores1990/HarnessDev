// Fase 6 (QA): casos límite del motor de cálculo que no cubría la fase 4.
// Puro: sin BD ni HTTP. IDs QA-xx referenciados en docs/06-qa/test-plan.md.
import { describe, expect, it } from "vitest";
import {
  calculateOrder,
  quoteOrder,
} from "../../src/services/pricing-engine/index.js";
import { vatOf } from "../../src/utils/money.js";
import {
  ING,
  custom,
  makeCatalog,
  makeIngredient,
  preset,
  uid,
} from "../helpers/catalog.js";

const codes = (violations) => violations.map((v) => v.code);

describe("QA-01 / US-10: IVA half-up exhaustivo contra aritmética entera", () => {
  // Referencia independiente: centavos enteros, IVA = floor((c * 15 + 50) / 100) (half-up exacto).
  const expectedVatCents = (cents) => Math.floor((cents * 15 + 50) / 100);
  const fmt = (cents) => (cents / 100).toFixed(2);

  it("para todos los subtotales de 0.00 a 200.00 (20 001 casos) el IVA coincide con half-up entero", () => {
    const mismatches = [];
    for (let cents = 0; cents <= 20000; cents += 1) {
      const t = calculateOrder([
        {
          unitSubtotalVat15: fmt(cents),
          unitSubtotalVat0: "0.00",
          quantity: 1,
          lineCalories: 0,
        },
      ]);
      const want = fmt(expectedVatCents(cents));
      if (t.vat15 !== want) mismatches.push([fmt(cents), t.vat15, want]);
      if (t.total !== fmt(cents + expectedVatCents(cents)))
        mismatches.push(["total", fmt(cents), t.total]);
    }
    expect(mismatches).toEqual([]);
  });

  it.each([
    ["0.03", "0.00"], // 0.0045 -> 0.00
    ["0.04", "0.01"], // 0.006 -> 0.01
    ["0.10", "0.02"], // 0.015 -> 0.02 (half-up; half-even daría 0.02 pero 0.30 -> 0.045 no)
    ["0.30", "0.05"], // 0.045 -> 0.05
    ["0.70", "0.11"], // 0.105 -> 0.11
    ["1.10", "0.17"], // 0.165 -> 0.17
    ["1.30", "0.20"], // 0.195 -> 0.20
    ["0.01", "0.00"], // 0.0015
    ["0.00", "0.00"],
  ])("subtotal 15 %% %s -> IVA %s", (sub15, vat) => {
    expect(
      calculateOrder([
        {
          unitSubtotalVat15: sub15,
          unitSubtotalVat0: "0.00",
          quantity: 1,
          lineCalories: 0,
        },
      ]).vat15,
    ).toBe(vat);
  });

  it("vatOf devuelve Decimal exacto, sin error de coma flotante (1.15 * 0.15)", () => {
    expect(vatOf("1.15").toFixed(2)).toBe("0.17"); // 0.1725
    expect(vatOf("2.35").toFixed(2)).toBe("0.35"); // 0.3525
  });

  it("el IVA 0 % no genera impuesto aunque el subtotal 0 % sea grande", () => {
    const t = calculateOrder([
      {
        unitSubtotalVat15: "0.00",
        unitSubtotalVat0: "99999.99",
        quantity: 1,
        lineCalories: 0,
      },
    ]);
    expect(t).toMatchObject({ vat15: "0.00", total: "99999.99" });
  });
});

describe("QA-02 / US-09: cantidad máxima por línea (20) y varias líneas", () => {
  const catalog = makeCatalog();
  const three = (extra) =>
    custom(
      [
        [ING.cheese, 3],
        [ING.ham, 1],
        [ING.mushroom, 1],
      ],
      extra,
    );

  it("20 pizzas: totales = 20 x unidad y stock requerido = 20 x porciones", () => {
    const r = quoteOrder([three({ quantity: 20 })], catalog);
    // unidad: 2.00+1.00+4.50+1.20+0.60 = 9.30 ; 0 %: 1.60 ; 15 %: 7.70
    expect(r.items[0]).toMatchObject({
      unitPrice: "9.30",
      lineSubtotal: "186.00",
      lineCalories: 20 * 795,
    });
    expect(r.totals).toEqual({
      subtotalVat15: "154.00",
      subtotalVat0: "32.00",
      vat15: "23.10",
      total: "209.10",
      totalCalories: 15900,
    });
    const need = Object.fromEntries(r.stock.map((s) => [s.name, s.required]));
    expect(need).toMatchObject({
      "Masa tradicional": 20,
      "Salsa de tomate": 20,
      "Queso mozzarella": 60,
      Jamón: 20,
      Champiñones: 20,
    });
  });

  it("stock exactamente igual a lo requerido con 20 pizzas es válido; con uno menos no", () => {
    const exact = makeCatalog();
    exact.ingredients.get(ING.cheese.id).stock = 60;
    expect(quoteOrder([three({ quantity: 20 })], exact).valid).toBe(true);
    exact.ingredients.get(ING.cheese.id).stock = 59;
    const r = quoteOrder([three({ quantity: 20 })], exact);
    expect(r.valid).toBe(false);
    expect(r.violations[0]).toMatchObject({
      code: "INSUFFICIENT_STOCK",
      meta: { name: "Queso mozzarella", requested: 60, available: 59 },
    });
  });

  it("dos líneas del mismo tamaño y distinto tamaño suman cada una con sus valores", () => {
    const a = three({ quantity: 1, sizeCode: "INDIVIDUAL" });
    const b = three({ quantity: 2, sizeCode: "FAMILY" });
    const r = quoteOrder([a, b], catalog);
    const unit = (item) => item.unitPrice;
    // INDIVIDUAL: 1.50+0.60+3.00+0.90+0.40 = 6.40 ; FAMILY: 3.00+1.50+6.60+1.80+0.90 = 13.80
    expect([unit(r.items[0]), unit(r.items[1])]).toEqual(["6.40", "13.80"]);
    expect(r.totals.subtotalVat15 + "|" + r.totals.subtotalVat0).toBe(
      // 15 %: (1.50+3.00+0.90)=5.40 + 2*(3.00+6.60+1.80)=22.80 -> 28.20 ; 0 %: (0.60+0.40)=1.00 + 2*(1.50+0.90)=4.80 -> 5.80
      "28.20|5.80",
    );
    expect(r.totals.vat15).toBe("4.23"); // 28.20 x 0.15 = 4.23
    expect(r.totals.total).toBe("38.23");
  });
});

describe("QA-03 / RF-10, RF-14: límites de porciones", () => {
  const catalog = makeCatalog();

  it("CUSTOM con 3 ingredientes distintos x 3 porciones cada uno es válido (máximo exacto)", () => {
    const r = quoteOrder(
      [
        custom([
          [ING.cheese, 3],
          [ING.ham, 3],
          [ING.mushroom, 3],
        ]),
      ],
      catalog,
    );
    expect(r.items[0].valid).toBe(true);
    expect(r.stock.find((s) => s.name === "Queso mozzarella").required).toBe(3);
  });

  it("predefinida: extra de un ingrediente que NO está en la receta acepta hasta 3", () => {
    const ok = quoteOrder([preset([[ING.ham, 3]])], catalog);
    expect(ok.items[0].valid).toBe(true);
    const bad = preset([[ING.ham, 3]]);
    bad.extras[0].portions = 4; // saltándose el esquema Zod: el motor también protege
    expect(codes(quoteOrder([bad], catalog).items[0].violations)).toContain(
      "MAX_PORTIONS_EXCEEDED",
    );
  });

  it("predefinida sin extras no pierde ni reduce ingredientes de la receta (solo se agrega)", () => {
    const r = quoteOrder([preset([[ING.ham, 1]])], catalog);
    const byCode = Object.fromEntries(
      r.items[0].components.map((c) => [c.code, c]),
    );
    expect(byCode["QUE-MOZ"]).toMatchObject({ portions: 2, recipePortions: 2 });
    expect(byCode["CAR-JAM"]).toMatchObject({ portions: 1, recipePortions: 0 });
    expect(byCode["MAS-TRA"].portions).toBe(1);
  });

  it("extra repetido sobre un ingrediente de la receta suma al máximo y la línea queda inválida", () => {
    const r = quoteOrder([preset([[ING.cheese, 2]])], catalog);
    expect(r.items[0].violations[0]).toMatchObject({
      code: "MAX_PORTIONS_EXCEEDED",
      meta: { max: 3, requested: 4 },
    });
  });
});

describe("QA-04 / US-18, RNF-04: tarifas de IVA y datos del cliente no confiables", () => {
  it("el motor ignora cualquier precio/IVA que venga en el ítem: solo usa el catálogo del servidor", () => {
    const item = custom([
      [ING.cheese, 1],
      [ING.ham, 1],
      [ING.mushroom, 1],
    ]);
    item.unitPrice = "0.01";
    item.total = "0.01";
    item.vatRatePercent = "0.00";
    const r = quoteOrder([item], makeCatalog());
    expect(r.items[0].unitPrice).toBe("6.30"); // 2.00+1.00+1.50+1.20+0.60
  });

  it("cambiar la tarifa de un ingrediente de 15 % a 0 % mueve su importe a Subtotal 0 % (US-18)", () => {
    const item = custom([
      [ING.cheese, 3],
      [ING.ham, 1],
      [ING.mushroom, 1],
    ]);
    const before = quoteOrder([item], makeCatalog()).totals;
    const cat = makeCatalog();
    cat.ingredients.get(ING.cheese.id).vatRatePercent = "0.00";
    const after = quoteOrder([item], cat).totals;
    expect(after.subtotalVat0).toBe("6.10"); // 1.60 + 4.50
    expect(after.subtotalVat15).toBe("3.20");
    expect(
      Number(before.subtotalVat15) + Number(before.subtotalVat0),
    ).toBeCloseTo(Number(after.subtotalVat15) + Number(after.subtotalVat0), 2);
  });

  it("ingrediente con precio 0.00 es válido y suma calorías sin costo", () => {
    const free = makeIngredient({
      n: 50,
      code: "OTR-GRA",
      name: "Orégano",
      categoryCode: "OTHER",
      prices: ["0.00", "0.00", "0.00"],
      calories: [1, 2, 3],
    });
    const cat = makeCatalog();
    cat.ingredients.set(free.id, free);
    const r = quoteOrder(
      [
        custom([
          [ING.cheese, 1],
          [ING.ham, 1],
          [free, 3],
        ]),
      ],
      cat,
    );
    expect(r.items[0].valid).toBe(true);
    expect(r.items[0].unitPrice).toBe("5.70"); // 2.00+1.00+1.50+1.20
    expect(r.items[0].unitCalories).toBe(300 + 60 + 110 + 90 + 6);
  });

  it("ingrediente cuyo stock es 0 hace inválido el pedido con INSUFFICIENT_STOCK (disponible 0)", () => {
    const cat = makeCatalog();
    cat.ingredients.get(ING.ham.id).stock = 0;
    const r = quoteOrder(
      [
        custom([
          [ING.cheese, 1],
          [ING.ham, 1],
          [ING.mushroom, 1],
        ]),
      ],
      cat,
    );
    expect(r.valid).toBe(false);
    expect(r.violations[0].meta).toMatchObject({ name: "Jamón", available: 0 });
  });

  it("cotización vacía de líneas inválidas no lanza (pedido sin ítems calculables)", () => {
    const r = quoteOrder(
      [
        {
          type: "PRESET",
          presetPizzaId: uid(999),
          sizeCode: "MEDIUM",
          quantity: 1,
        },
      ],
      makeCatalog(),
    );
    expect(codes(r.items[0].violations)).toEqual(["PRESET_NOT_FOUND"]);
    expect(r.totals).toMatchObject({ total: "0.00", totalCalories: 0 });
  });
});

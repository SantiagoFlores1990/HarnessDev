import { describe, expect, it } from "vitest";
import {
  calculateOrder,
  presetAvailability,
  quoteOrder,
  validateRecipe,
} from "../../src/services/pricing-engine/index.js";
import {
  ING,
  PRESET_MARGHERITA,
  custom,
  makeCatalog,
  preset,
  uid,
} from "../helpers/catalog.js";

const codes = (violations) => violations.map((v) => v.code);
const itemCodes = (result, i = 0) => codes(result.items[i].violations);

describe("Motor de cálculo: precio y calorías", () => {
  it("UT-B01 / US-07: MEDIUM masa 2.00 + salsa 1.00 + queso 1.50 x3 = 7.50 sin IVA", () => {
    const r = quoteOrder(
      [
        custom([
          [ING.cheese, 3],
          [ING.ham, 1],
          [ING.mushroom, 1],
        ]),
      ],
      makeCatalog(),
    );
    // solo el queso x3 más la base (para comprobar la fórmula del ejemplo, ver el siguiente test completo)
    const base = quoteOrder([custom([[ING.cheese, 3]])], makeCatalog());
    expect(base.items[0].unitPrice).toBe("7.50");
    expect(base.items[0].unitCalories).toBe(300 + 60 + 330);
    expect(r.items[0].valid).toBe(true);
  });

  it("ejemplo de referencia del contrato §4 (cantidad 2): 9.50, 820 kcal, totales 21.31", () => {
    const r = quoteOrder(
      [
        custom(
          [
            [ING.cheese, 3],
            [ING.ham, 1],
            [ING.pineapple, 1],
          ],
          { quantity: 2 },
        ),
      ],
      makeCatalog(),
    );
    const p = r.items[0];
    expect(p.unitPrice).toBe("9.50");
    expect(p.unitCalories).toBe(820);
    expect(p.unitSubtotalVat15).toBe("7.70");
    expect(p.unitSubtotalVat0).toBe("1.80");
    expect(p.lineSubtotal).toBe("19.00");
    expect(p.lineCalories).toBe(1640);
    expect(r.totals).toEqual({
      subtotalVat15: "15.40",
      subtotalVat0: "3.60",
      vat15: "2.31",
      total: "21.31",
      totalCalories: 1640,
    });
    expect(r.valid).toBe(true);
  });

  it("el precio depende del tamaño (valores distintos, sin factor fijo)", () => {
    const r = quoteOrder(
      ["INDIVIDUAL", "MEDIUM", "FAMILY"].map((sizeCode) =>
        custom(
          [
            [ING.cheese, 1],
            [ING.ham, 1],
            [ING.mushroom, 1],
          ],
          { sizeCode },
        ),
      ),
      makeCatalog(),
    );
    // Individual: 1.50 + 0.60 + 1.00 + 0.90 + 0.40 = 4.40
    // Mediana:    2.00 + 1.00 + 1.50 + 1.20 + 0.60 = 6.30
    // Familiar:   3.00 + 1.50 + 2.20 + 1.80 + 0.90 = 9.40
    expect(r.items.map((i) => i.unitPrice)).toEqual(["4.40", "6.30", "9.40"]);
    expect(r.items.map((i) => i.unitCalories)).toEqual([360, 575, 852]);
  });

  it("cada componente informa precio, calorías y tarifa de IVA del tamaño elegido", () => {
    const r = quoteOrder([custom([[ING.cheese, 3]])], makeCatalog());
    const cheese = r.items[0].components.find((c) => c.component === "TOPPING");
    expect(cheese).toMatchObject({
      code: "QUE-MOZ",
      portions: 3,
      recipePortions: 0,
      unitPrice: "1.50",
      unitCalories: 110,
      vatRatePercent: "15.00",
      lineAmount: "4.50",
      lineCalories: 330,
    });
    const sauce = r.items[0].components.find((c) => c.component === "SAUCE");
    expect(sauce.vatRatePercent).toBe("0.00");
  });
});

describe("Motor de cálculo: IVA 15 % / 0 % y redondeo half-up (US-10)", () => {
  const order = (sub15, sub0, quantity = 1) =>
    calculateOrder([
      {
        unitSubtotalVat15: sub15,
        unitSubtotalVat0: sub0,
        quantity,
        lineCalories: 0,
      },
    ]);

  it("UT-B02: 0.35 -> IVA 0.05 (0.0525)", () => {
    expect(order("0.35", "0.00").vat15).toBe("0.05");
  });
  it("UT-B02: 0.30 -> IVA 0.05 (0.045 half-up)", () => {
    expect(order("0.30", "0.00").vat15).toBe("0.05");
  });
  it("10.00 al 15 % y 2.00 al 0 % -> IVA 1.50 y total 13.50", () => {
    const t = order("10.00", "2.00");
    expect(t.vat15).toBe("1.50");
    expect(t.total).toBe("13.50");
  });
  it("6.50 -> IVA 0.98 (0.975 half-up) y total = sub15 + sub0 + IVA", () => {
    const t = order("6.50", "1.00");
    expect(t.vat15).toBe("0.98");
    expect(t.total).toBe("8.48");
  });
  it("el IVA se calcula una vez sobre el subtotal del pedido, no por línea", () => {
    const t = calculateOrder([
      {
        unitSubtotalVat15: "0.30",
        unitSubtotalVat0: "0.00",
        quantity: 1,
        lineCalories: 0,
      },
      {
        unitSubtotalVat15: "0.30",
        unitSubtotalVat0: "0.00",
        quantity: 1,
        lineCalories: 0,
      },
    ]);
    expect(t.subtotalVat15).toBe("0.60");
    expect(t.vat15).toBe("0.09"); // por línea habría sido 0.05 + 0.05 = 0.10
  });
  it("solo componentes al 0 % -> IVA 0.00", () => {
    const t = order("0.00", "5.00");
    expect(t.vat15).toBe("0.00");
    expect(t.total).toBe("5.00");
  });
  it("multiplica por la cantidad antes de sumar", () => {
    const t = order("7.70", "1.80", 2);
    expect(t.subtotalVat15).toBe("15.40");
    expect(t.subtotalVat0).toBe("3.60");
  });
});

describe("Motor de cálculo: reglas de armado", () => {
  it("UT-B03: menos de 3 ingredientes distintos en CUSTOM -> MIN_TOPPINGS_NOT_MET", () => {
    const r = quoteOrder(
      [
        custom([
          [ING.cheese, 3],
          [ING.ham, 1],
        ]),
      ],
      makeCatalog(),
    );
    expect(itemCodes(r)).toContain("MIN_TOPPINGS_NOT_MET");
    expect(
      r.items[0].violations.find((v) => v.code === "MIN_TOPPINGS_NOT_MET").meta,
    ).toEqual({
      min: 3,
      current: 2,
    });
    expect(r.valid).toBe(false);
  });
  it("triple queso (una sola porción distinta x3) no alcanza el mínimo de 3 distintos", () => {
    const r = quoteOrder([custom([[ING.cheese, 3]])], makeCatalog());
    expect(itemCodes(r)).toEqual(["MIN_TOPPINGS_NOT_MET"]);
    // el cálculo parcial en vivo igualmente devuelve el precio
    expect(r.items[0].unitPrice).toBe("7.50");
  });
  it("3 ingredientes distintos cumplen el mínimo", () => {
    const r = quoteOrder(
      [
        custom([
          [ING.cheese, 1],
          [ING.ham, 1],
          [ING.mushroom, 1],
        ]),
      ],
      makeCatalog(),
    );
    expect(r.items[0].valid).toBe(true);
  });
  it("UT-B04: predefinida con 1 topping distinto y sin extras es válida (el mínimo no aplica)", () => {
    const r = quoteOrder([preset()], makeCatalog());
    expect(r.items[0].valid).toBe(true);
    expect(r.valid).toBe(true);
    // 2.00 + 1.00 + 1.50 x2 = 6.00
    expect(r.items[0].unitPrice).toBe("6.00");
    expect(r.items[0].presetPizza).toEqual({
      id: PRESET_MARGHERITA.id,
      code: "MARGHERITA",
      name: "Margarita",
    });
  });
  it("el mínimo de 3 tampoco se exige al personalizar agregando extras a una predefinida", () => {
    const r = quoteOrder([preset([[ING.ham, 1]])], makeCatalog());
    expect(r.items[0].valid).toBe(true);
  });
  it("predefinida: las porciones de la receta cuentan para el máximo (receta 2 + extra 2 = 4)", () => {
    const r = quoteOrder([preset([[ING.cheese, 2]])], makeCatalog());
    expect(itemCodes(r)).toContain("MAX_PORTIONS_EXCEEDED");
    const v = r.items[0].violations.find(
      (x) => x.code === "MAX_PORTIONS_EXCEEDED",
    );
    expect(v.meta).toEqual({ max: 3, requested: 4 });
    expect(v.ingredientId).toBe(ING.cheese.id);
  });
  it("predefinida: receta 2 + extra 1 = 3 es válido y la línea informa recipePortions", () => {
    const r = quoteOrder([preset([[ING.cheese, 1]])], makeCatalog());
    expect(r.items[0].valid).toBe(true);
    const c = r.items[0].components.find((x) => x.code === "QUE-MOZ");
    expect(c).toMatchObject({ portions: 3, recipePortions: 2 });
  });
  it("UT-B05: 4 porciones del mismo ingrediente en CUSTOM -> MAX_PORTIONS_EXCEEDED", () => {
    const r = quoteOrder(
      [
        custom([
          [ING.cheese, 4],
          [ING.ham, 1],
          [ING.mushroom, 1],
        ]),
      ],
      makeCatalog(),
    );
    expect(itemCodes(r)).toContain("MAX_PORTIONS_EXCEEDED");
  });
  it("UT-B06: sin masa -> DOUGH_REQUIRED; sin salsa -> SAUCE_REQUIRED", () => {
    const r = quoteOrder(
      [
        custom(
          [
            [ING.cheese, 1],
            [ING.ham, 1],
            [ING.mushroom, 1],
          ],
          { doughId: undefined, sauceId: null },
        ),
      ],
      makeCatalog(),
    );
    expect(itemCodes(r)).toEqual(
      expect.arrayContaining(["DOUGH_REQUIRED", "SAUCE_REQUIRED"]),
    );
  });
  it("UT-B06: una masa como topping -> INGREDIENT_CATEGORY_NOT_ALLOWED", () => {
    const r = quoteOrder(
      [
        custom([
          [ING.dough2, 1],
          [ING.cheese, 1],
          [ING.ham, 1],
          [ING.mushroom, 1],
        ]),
      ],
      makeCatalog(),
    );
    expect(itemCodes(r)).toContain("INGREDIENT_CATEGORY_NOT_ALLOWED");
  });
  it("una salsa como extra de predefinida -> INGREDIENT_CATEGORY_NOT_ALLOWED", () => {
    const catalog = makeCatalog();
    const sauce2 = { ...ING.sauce, id: uid(77), code: "SAL-X" };
    catalog.ingredients.set(sauce2.id, sauce2);
    const r = quoteOrder([preset([[sauce2, 1]])], catalog);
    expect(itemCodes(r)).toContain("INGREDIENT_CATEGORY_NOT_ALLOWED");
  });
  it("doughId que no es una masa -> INVALID_DOUGH; sauceId que no es salsa -> INVALID_SAUCE", () => {
    const r = quoteOrder(
      [
        custom(
          [
            [ING.cheese, 1],
            [ING.ham, 1],
            [ING.mushroom, 1],
          ],
          { doughId: ING.cheese.id, sauceId: ING.ham.id },
        ),
      ],
      makeCatalog(),
    );
    expect(itemCodes(r)).toEqual(
      expect.arrayContaining(["INVALID_DOUGH", "INVALID_SAUCE"]),
    );
  });
  it("ingrediente repetido -> DUPLICATE_INGREDIENT (no se suma dos veces)", () => {
    const r = quoteOrder(
      [
        custom([
          [ING.cheese, 1],
          [ING.cheese, 1],
          [ING.ham, 1],
          [ING.mushroom, 1],
        ]),
      ],
      makeCatalog(),
    );
    expect(itemCodes(r)).toContain("DUPLICATE_INGREDIENT");
    expect(
      r.items[0].components.filter((c) => c.code === "QUE-MOZ"),
    ).toHaveLength(1);
  });
  it("ingrediente inexistente -> INGREDIENT_NOT_FOUND", () => {
    const r = quoteOrder(
      [
        {
          ...custom([
            [ING.cheese, 1],
            [ING.ham, 1],
            [ING.mushroom, 1],
          ]),
          toppings: [{ ingredientId: uid(999), portions: 1 }],
        },
      ],
      makeCatalog(),
    );
    expect(itemCodes(r)).toContain("INGREDIENT_NOT_FOUND");
  });
  it("ingrediente inactivo -> INGREDIENT_INACTIVE y no suma al precio", () => {
    const catalog = makeCatalog();
    catalog.ingredients.get(ING.ham.id).active = false;
    const r = quoteOrder(
      [
        custom([
          [ING.cheese, 1],
          [ING.ham, 1],
          [ING.mushroom, 1],
        ]),
      ],
      catalog,
    );
    expect(itemCodes(r)).toContain("INGREDIENT_INACTIVE");
    expect(r.items[0].components.map((c) => c.code)).not.toContain("CAR-JAM");
  });
  it("ingrediente sin valores para el tamaño -> MISSING_SIZE_VALUES", () => {
    const catalog = makeCatalog();
    delete catalog.ingredients.get(ING.ham.id).sizeValues.FAMILY;
    const r = quoteOrder(
      [
        custom(
          [
            [ING.cheese, 1],
            [ING.ham, 1],
            [ING.mushroom, 1],
          ],
          { sizeCode: "FAMILY" },
        ),
      ],
      catalog,
    );
    expect(itemCodes(r)).toContain("MISSING_SIZE_VALUES");
  });
  it("predefinida inexistente o inactiva -> PRESET_NOT_FOUND / PRESET_INACTIVE", () => {
    const catalog = makeCatalog();
    expect(
      itemCodes(quoteOrder([preset([], { presetPizzaId: uid(404) })], catalog)),
    ).toEqual(["PRESET_NOT_FOUND"]);
    catalog.presets.get(PRESET_MARGHERITA.id).active = false;
    expect(itemCodes(quoteOrder([preset()], catalog))).toContain(
      "PRESET_INACTIVE",
    );
  });
  it("predefinida con ingrediente de receta inactivo -> PRESET_UNAVAILABLE (S-25)", () => {
    const catalog = makeCatalog();
    catalog.ingredients.get(ING.cheese.id).active = false;
    const r = quoteOrder([preset()], catalog);
    expect(itemCodes(r)).toContain("PRESET_UNAVAILABLE");
  });
});

describe("Motor de cálculo: stock agregado", () => {
  it("UT-B07: masa compartida entre líneas y cantidades se suma (masa 2 x ... )", () => {
    const catalog = makeCatalog();
    catalog.ingredients.get(ING.dough.id).stock = 5;
    const r = quoteOrder(
      [
        custom(
          [
            [ING.cheese, 1],
            [ING.ham, 1],
            [ING.mushroom, 1],
          ],
          { quantity: 3 },
        ),
        custom(
          [
            [ING.cheese, 1],
            [ING.ham, 1],
            [ING.olives, 1],
          ],
          { quantity: 3 },
        ),
      ],
      catalog,
    );
    const dough = r.stock.find((s) => s.name === "Masa tradicional");
    expect(dough).toEqual({
      ingredientId: ING.dough.id,
      name: "Masa tradicional",
      required: 6,
      available: 5,
    });
    expect(r.valid).toBe(false);
    const v = r.violations.find((x) => x.code === "INSUFFICIENT_STOCK");
    expect(v.meta).toMatchObject({
      requested: 6,
      available: 5,
      name: "Masa tradicional",
    });
    expect(v.message).toContain("solicitado 6, disponible 5");
  });
  it("contrato §4: requerido masa 2, salsa 2, queso 6, jamón 2, piña 2 (cantidad 2)", () => {
    const r = quoteOrder(
      [
        custom(
          [
            [ING.cheese, 3],
            [ING.ham, 1],
            [ING.pineapple, 1],
          ],
          { quantity: 2 },
        ),
      ],
      makeCatalog(),
    );
    const need = Object.fromEntries(r.stock.map((s) => [s.name, s.required]));
    expect(need).toEqual({
      "Masa tradicional": 2,
      "Salsa de tomate": 2,
      "Queso mozzarella": 6,
      Jamón: 2,
      Piña: 2,
    });
  });
  it("una predefinida cuenta receta + extras en el stock", () => {
    const r = quoteOrder(
      [preset([[ING.cheese, 1]], { quantity: 2 })],
      makeCatalog(),
    );
    expect(r.stock.find((s) => s.name === "Queso mozzarella").required).toBe(6); // (2 + 1) x 2
  });
  it("con stock exacto el pedido es válido", () => {
    const catalog = makeCatalog();
    catalog.ingredients.get(ING.cheese.id).stock = 3;
    const r = quoteOrder([custom([[ING.cheese, 3]])], catalog);
    expect(r.violations).toEqual([]);
  });
  it("requisitos ordenados por id (evita interbloqueos)", () => {
    const r = quoteOrder(
      [
        custom([
          [ING.mushroom, 1],
          [ING.ham, 1],
          [ING.cheese, 1],
        ]),
      ],
      makeCatalog(),
    );
    const ids = r.requirements.map((x) => x.ingredientId);
    expect(ids).toEqual([...ids].sort());
  });
});

describe("Motor de cálculo: cálculo parcial y respuesta", () => {
  it("con violaciones calcula con los componentes válidos presentes", () => {
    const r = quoteOrder(
      [custom([[ING.cheese, 1]], { doughId: undefined })],
      makeCatalog(),
    );
    expect(r.items[0].components.map((c) => c.component)).toEqual([
      "SAUCE",
      "TOPPING",
    ]);
    expect(r.items[0].unitPrice).toBe("2.50");
    expect(r.valid).toBe(false);
  });
  it("estructura PricedPizza completa", () => {
    const r = quoteOrder(
      [
        custom([
          [ING.cheese, 1],
          [ING.ham, 1],
          [ING.mushroom, 1],
        ]),
      ],
      makeCatalog(),
    );
    expect(Object.keys(r.items[0]).sort()).toEqual(
      [
        "components",
        "index",
        "lineCalories",
        "lineSubtotal",
        "presetPizza",
        "quantity",
        "size",
        "type",
        "unitCalories",
        "unitPrice",
        "unitSubtotalVat0",
        "unitSubtotalVat15",
        "valid",
        "violations",
      ].sort(),
    );
    expect(r.items[0].size).toEqual({ code: "MEDIUM", name: "Mediana" });
  });
  it("varias líneas conservan el índice para ubicar la violación", () => {
    const r = quoteOrder(
      [
        custom([
          [ING.cheese, 1],
          [ING.ham, 1],
          [ING.mushroom, 1],
        ]),
        custom([[ING.cheese, 1]]),
      ],
      makeCatalog(),
    );
    expect(r.items[0].valid).toBe(true);
    expect(r.items[1].violations[0]).toMatchObject({
      code: "MIN_TOPPINGS_NOT_MET",
      itemIndex: 1,
    });
  });
});

describe("Receta de predefinida (validateRecipe) y disponibilidad", () => {
  const entry = (ing, portions = 1) => ({ ingredientId: ing.id, portions });

  it("receta válida sin mínimo de toppings", () => {
    expect(
      validateRecipe([entry(ING.dough), entry(ING.sauce)], makeCatalog()),
    ).toEqual([]);
  });
  it("sin masa / sin salsa", () => {
    expect(codes(validateRecipe([entry(ING.cheese)], makeCatalog()))).toEqual([
      "DOUGH_REQUIRED",
      "SAUCE_REQUIRED",
    ]);
  });
  it("dos masas -> INGREDIENT_CATEGORY_NOT_ALLOWED", () => {
    const v = validateRecipe(
      [entry(ING.dough), entry(ING.dough2), entry(ING.sauce)],
      makeCatalog(),
    );
    expect(codes(v)).toContain("INGREDIENT_CATEGORY_NOT_ALLOWED");
  });
  it("porciones > 3 en topping o > 1 en masa -> MAX_PORTIONS_EXCEEDED", () => {
    const v = validateRecipe(
      [entry(ING.dough, 2), entry(ING.sauce), entry(ING.cheese, 4)],
      makeCatalog(),
    );
    expect(codes(v).filter((c) => c === "MAX_PORTIONS_EXCEEDED")).toHaveLength(
      2,
    );
  });
  it("repetidos e inexistentes", () => {
    const v = validateRecipe(
      [
        entry(ING.dough),
        entry(ING.sauce),
        entry(ING.cheese),
        entry(ING.cheese),
        { ingredientId: uid(999), portions: 1 },
      ],
      makeCatalog(),
    );
    expect(codes(v)).toEqual(
      expect.arrayContaining(["DUPLICATE_INGREDIENT", "INGREDIENT_NOT_FOUND"]),
    );
  });
  it("presetAvailability: disponible con stock suficiente", () => {
    const c = makeCatalog();
    expect(presetAvailability(c.presets.get(PRESET_MARGHERITA.id), c)).toEqual(
      [],
    );
  });
  it("presetAvailability: sin stock para 1 pizza -> PRESET_UNAVAILABLE OUT_OF_STOCK", () => {
    const c = makeCatalog();
    c.ingredients.get(ING.cheese.id).stock = 1; // la receta pide 2
    const v = presetAvailability(c.presets.get(PRESET_MARGHERITA.id), c);
    expect(v[0]).toMatchObject({
      code: "PRESET_UNAVAILABLE",
      meta: { reason: "OUT_OF_STOCK", requested: 2, available: 1 },
    });
  });
  it("presetAvailability: ingrediente inactivo, inactiva la pizza y valores faltantes", () => {
    const c = makeCatalog();
    c.ingredients.get(ING.sauce.id).active = false;
    delete c.ingredients.get(ING.cheese.id).sizeValues.MEDIUM;
    const p = c.presets.get(PRESET_MARGHERITA.id);
    p.active = false;
    const reasons = presetAvailability(p, c).map(
      (v) => v.meta.reason ?? v.code,
    );
    expect(reasons).toEqual([
      "PRESET_INACTIVE",
      "INACTIVE",
      "MISSING_SIZE_VALUES",
    ]);
  });
});

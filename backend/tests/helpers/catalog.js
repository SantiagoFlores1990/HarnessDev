// Fábricas de catálogo para probar el motor sin base de datos.
export const uid = (n) =>
  `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;

export function makeIngredient({
  n,
  code,
  name,
  categoryCode,
  vat = "15.00",
  stock = 100,
  active = true,
  prices,
  calories,
}) {
  const sizeValues = {};
  if (prices) {
    ["INDIVIDUAL", "MEDIUM", "FAMILY"].forEach((s, i) => {
      if (prices[i] !== null)
        sizeValues[s] = { price: prices[i], calories: calories[i] };
    });
  }
  return {
    id: uid(n),
    code,
    name,
    categoryCode,
    active,
    stock,
    vatRatePercent: vat,
    sizeValues,
  };
}

export const ING = {
  dough: makeIngredient({
    n: 1,
    code: "MAS-TRA",
    name: "Masa tradicional",
    categoryCode: "DOUGH",
    prices: ["1.50", "2.00", "3.00"],
    calories: [180, 300, 450],
  }),
  sauce: makeIngredient({
    n: 2,
    code: "SAL-TOM",
    name: "Salsa de tomate",
    categoryCode: "SAUCE",
    vat: "0.00",
    prices: ["0.60", "1.00", "1.50"],
    calories: [30, 60, 90],
  }),
  cheese: makeIngredient({
    n: 3,
    code: "QUE-MOZ",
    name: "Queso mozzarella",
    categoryCode: "CHEESE",
    prices: ["1.00", "1.50", "2.20"],
    calories: [80, 110, 160],
  }),
  ham: makeIngredient({
    n: 4,
    code: "CAR-JAM",
    name: "Jamón",
    categoryCode: "MEAT",
    prices: ["0.90", "1.20", "1.80"],
    calories: [60, 90, 130],
  }),
  pineapple: makeIngredient({
    n: 5,
    code: "OTR-PIN",
    name: "Piña",
    categoryCode: "OTHER",
    vat: "0.00",
    prices: ["0.50", "0.80", "1.10"],
    calories: [25, 40, 60],
  }),
  mushroom: makeIngredient({
    n: 6,
    code: "VEG-CHA",
    name: "Champiñones",
    categoryCode: "VEGETABLE",
    vat: "0.00",
    prices: ["0.40", "0.60", "0.90"],
    calories: [10, 15, 22],
  }),
  olives: makeIngredient({
    n: 7,
    code: "VEG-ACE",
    name: "Aceitunas",
    categoryCode: "VEGETABLE",
    prices: ["0.50", "0.70", "1.00"],
    calories: [25, 40, 60],
  }),
  dough2: makeIngredient({
    n: 8,
    code: "MAS-INT",
    name: "Masa integral",
    categoryCode: "DOUGH",
    prices: ["1.80", "2.40", "3.50"],
    calories: [170, 280, 420],
  }),
};

export const PRESET_MARGHERITA = {
  id: uid(100),
  code: "MARGHERITA",
  name: "Margarita",
  active: true,
  // masa + salsa + 2 porciones de queso (solo 1 topping distinto: válido en predefinidas, S-17)
  recipe: [
    { ingredientId: ING.dough.id, portions: 1 },
    { ingredientId: ING.sauce.id, portions: 1 },
    { ingredientId: ING.cheese.id, portions: 2 },
  ],
};

/** Catálogo fresco (copias) para que cada prueba pueda mutarlo sin afectar a otras. */
export function makeCatalog(overrides = {}) {
  const clone = (o) => JSON.parse(JSON.stringify(o));
  const ingredients = new Map(Object.values(ING).map((i) => [i.id, clone(i)]));
  const presets = new Map([[PRESET_MARGHERITA.id, clone(PRESET_MARGHERITA)]]);
  const catalog = {
    sizes: {
      INDIVIDUAL: { id: 1, code: "INDIVIDUAL", name: "Individual" },
      MEDIUM: { id: 2, code: "MEDIUM", name: "Mediana" },
      FAMILY: { id: 3, code: "FAMILY", name: "Familiar" },
    },
    ingredients,
    presets,
  };
  return Object.assign(catalog, overrides);
}

export const custom = (toppings, extra = {}) => ({
  type: "CUSTOM",
  sizeCode: "MEDIUM",
  doughId: ING.dough.id,
  sauceId: ING.sauce.id,
  toppings: toppings.map(([ing, portions]) => ({
    ingredientId: ing.id,
    portions,
  })),
  quantity: 1,
  ...extra,
});

export const preset = (extras = [], extra = {}) => ({
  type: "PRESET",
  presetPizzaId: PRESET_MARGHERITA.id,
  sizeCode: "MEDIUM",
  extras: extras.map(([ing, portions]) => ({ ingredientId: ing.id, portions })),
  quantity: 1,
  ...extra,
});

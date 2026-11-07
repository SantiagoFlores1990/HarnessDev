// Funciones del seed (idempotentes: upsert por code/email). DATOS DE EJEMPLO, no precios reales.
// Las usan prisma/seed.js y las pruebas de integración (solo contra el esquema `test`).
import bcrypt from "bcryptjs";
import crypto from "node:crypto";

const ROLES = [
  { code: "ADMIN", name: "Administrador" },
  { code: "CLIENT", name: "Cliente" },
];
const SIZES = [
  { code: "INDIVIDUAL", name: "Individual", sortOrder: 1 },
  { code: "MEDIUM", name: "Mediana", sortOrder: 2 },
  { code: "FAMILY", name: "Familiar", sortOrder: 3 },
];
const CATEGORIES = [
  { code: "DOUGH", name: "Masa", sortOrder: 1 },
  { code: "SAUCE", name: "Salsa", sortOrder: 2 },
  { code: "CHEESE", name: "Queso", sortOrder: 3 },
  { code: "MEAT", name: "Carne", sortOrder: 4 },
  { code: "VEGETABLE", name: "Vegetal", sortOrder: 5 },
  { code: "OTHER", name: "Otros", sortOrder: 6 },
];
const VAT_RATES = [
  { code: "VAT_15", name: "IVA 15 %", ratePercent: "15.00", isDefault: true },
  { code: "VAT_0", name: "IVA 0 %", ratePercent: "0.00", isDefault: false },
];

// [code, name, category, vat, stock, [precio indiv, mediana, familiar], [kcal indiv, mediana, familiar]]
export const SAMPLE_INGREDIENTS = [
  [
    "MAS-TRA",
    "Masa tradicional",
    "DOUGH",
    "VAT_15",
    300,
    ["1.50", "2.00", "3.00"],
    [180, 300, 450],
  ],
  [
    "MAS-INT",
    "Masa integral",
    "DOUGH",
    "VAT_15",
    200,
    ["1.80", "2.40", "3.50"],
    [170, 280, 420],
  ],
  [
    "MAS-FIN",
    "Masa fina",
    "DOUGH",
    "VAT_15",
    200,
    ["1.60", "2.10", "3.10"],
    [150, 250, 380],
  ],
  [
    "SAL-TOM",
    "Salsa de tomate",
    "SAUCE",
    "VAT_0",
    300,
    ["0.60", "1.00", "1.50"],
    [30, 60, 90],
  ],
  [
    "SAL-BBQ",
    "Salsa BBQ",
    "SAUCE",
    "VAT_15",
    150,
    ["0.70", "1.10", "1.60"],
    [50, 90, 130],
  ],
  [
    "SAL-BLA",
    "Salsa blanca",
    "SAUCE",
    "VAT_15",
    150,
    ["0.80", "1.20", "1.80"],
    [70, 120, 180],
  ],
  [
    "QUE-MOZ",
    "Queso mozzarella",
    "CHEESE",
    "VAT_15",
    400,
    ["0.80", "1.20", "1.80"],
    [60, 90, 130],
  ],
  [
    "QUE-CHE",
    "Queso cheddar",
    "CHEESE",
    "VAT_15",
    200,
    ["0.90", "1.30", "1.90"],
    [70, 100, 145],
  ],
  [
    "QUE-PAR",
    "Queso parmesano",
    "CHEESE",
    "VAT_15",
    150,
    ["1.00", "1.50", "2.20"],
    [55, 80, 120],
  ],
  [
    "QUE-GOR",
    "Queso gorgonzola",
    "CHEESE",
    "VAT_15",
    120,
    ["1.10", "1.60", "2.40"],
    [65, 95, 140],
  ],
  [
    "CAR-PEP",
    "Pepperoni",
    "MEAT",
    "VAT_15",
    250,
    ["1.10", "1.60", "2.40"],
    [80, 120, 180],
  ],
  [
    "CAR-JAM",
    "Jamón",
    "MEAT",
    "VAT_15",
    250,
    ["1.00", "1.50", "2.20"],
    [50, 75, 110],
  ],
  [
    "CAR-TOC",
    "Tocino",
    "MEAT",
    "VAT_15",
    150,
    ["1.20", "1.80", "2.60"],
    [90, 135, 200],
  ],
  [
    "CAR-POL",
    "Pollo",
    "MEAT",
    "VAT_15",
    150,
    ["1.20", "1.70", "2.50"],
    [55, 80, 120],
  ],
  [
    "VEG-CHA",
    "Champiñones",
    "VEGETABLE",
    "VAT_0",
    200,
    ["0.60", "0.90", "1.30"],
    [10, 15, 22],
  ],
  [
    "VEG-PIM",
    "Pimiento",
    "VEGETABLE",
    "VAT_0",
    200,
    ["0.50", "0.80", "1.20"],
    [8, 12, 18],
  ],
  [
    "VEG-CEB",
    "Cebolla",
    "VEGETABLE",
    "VAT_0",
    200,
    ["0.40", "0.60", "0.90"],
    [10, 15, 22],
  ],
  [
    "VEG-ACE",
    "Aceitunas",
    "VEGETABLE",
    "VAT_15",
    150,
    ["0.70", "1.00", "1.50"],
    [25, 40, 60],
  ],
  [
    "VEG-ALB",
    "Albahaca",
    "VEGETABLE",
    "VAT_0",
    150,
    ["0.30", "0.50", "0.70"],
    [2, 4, 6],
  ],
  [
    "OTR-PIN",
    "Piña",
    "OTHER",
    "VAT_0",
    150,
    ["0.70", "1.00", "1.50"],
    [25, 40, 60],
  ],
];

// [code, nombre, descripción, orden, [[código ingrediente, porciones], ...]]
export const SAMPLE_PRESETS = [
  [
    "MARGHERITA",
    "Margarita",
    "Tomate, mozzarella y albahaca",
    1,
    [
      ["MAS-TRA", 1],
      ["SAL-TOM", 1],
      ["QUE-MOZ", 2],
      ["VEG-ALB", 1],
    ],
  ],
  [
    "PEPPERONI",
    "Pepperoni",
    "Mozzarella y abundante pepperoni",
    2,
    [
      ["MAS-TRA", 1],
      ["SAL-TOM", 1],
      ["QUE-MOZ", 1],
      ["CAR-PEP", 3],
    ],
  ],
  [
    "HAWAIIAN",
    "Hawaiana",
    "Jamón y piña con mozzarella",
    3,
    [
      ["MAS-TRA", 1],
      ["SAL-TOM", 1],
      ["QUE-MOZ", 1],
      ["CAR-JAM", 2],
      ["OTR-PIN", 1],
    ],
  ],
  [
    "VEGETARIAN",
    "Vegetariana",
    "Champiñones, pimiento, cebolla y aceitunas",
    4,
    [
      ["MAS-INT", 1],
      ["SAL-TOM", 1],
      ["QUE-MOZ", 1],
      ["VEG-CHA", 1],
      ["VEG-PIM", 1],
      ["VEG-CEB", 1],
      ["VEG-ACE", 1],
    ],
  ],
  [
    "FOUR_CHEESE",
    "4 Quesos",
    "Mozzarella, cheddar, parmesano y gorgonzola",
    5,
    [
      ["MAS-TRA", 1],
      ["SAL-BLA", 1],
      ["QUE-MOZ", 1],
      ["QUE-CHE", 1],
      ["QUE-PAR", 1],
      ["QUE-GOR", 1],
    ],
  ],
];

/** Roles, tamaños, categorías y tarifas de IVA (datos de referencia). */
export async function seedReference(prisma) {
  for (const r of ROLES) {
    await prisma.role.upsert({
      where: { code: r.code },
      update: { name: r.name },
      create: r,
    });
  }
  for (const s of SIZES) {
    await prisma.size.upsert({
      where: { code: s.code },
      update: { name: s.name, sortOrder: s.sortOrder },
      create: s,
    });
  }
  for (const c of CATEGORIES) {
    await prisma.ingredientCategory.upsert({
      where: { code: c.code },
      update: { name: c.name, sortOrder: c.sortOrder },
      create: c,
    });
  }
  for (const v of VAT_RATES) {
    await prisma.vatRate.upsert({
      where: { code: v.code },
      update: { name: v.name, isDefault: v.isDefault },
      create: v,
    });
  }
}

/**
 * Ingredientes de ejemplo. No se pisan cambios del administrador: si el ingrediente existe,
 * no se modifica (precio, stock, etc.); solo se completan valores de tamaño que falten.
 */
export async function seedIngredients(prisma) {
  const [categories, vats, sizes] = await Promise.all([
    prisma.ingredientCategory.findMany(),
    prisma.vatRate.findMany(),
    prisma.size.findMany(),
  ]);
  const cat = Object.fromEntries(categories.map((c) => [c.code, c.id]));
  const vat = Object.fromEntries(vats.map((v) => [v.code, v.id]));
  const size = Object.fromEntries(sizes.map((s) => [s.code, s.id]));
  const sizeCodes = ["INDIVIDUAL", "MEDIUM", "FAMILY"];

  for (const [
    code,
    name,
    category,
    vatCode,
    stock,
    prices,
    calories,
  ] of SAMPLE_INGREDIENTS) {
    const ingredient = await prisma.ingredient.upsert({
      where: { code },
      update: {},
      create: {
        code,
        name,
        categoryId: cat[category],
        vatRateId: vat[vatCode],
        stock,
        active: true,
      },
    });
    for (let i = 0; i < sizeCodes.length; i += 1) {
      await prisma.ingredientSizeValue.upsert({
        where: {
          ingredientId_sizeId: {
            ingredientId: ingredient.id,
            sizeId: size[sizeCodes[i]],
          },
        },
        update: {},
        create: {
          ingredientId: ingredient.id,
          sizeId: size[sizeCodes[i]],
          price: prices[i],
          calories: calories[i],
        },
      });
    }
  }
}

/** Las 5 predefinidas. Si ya existen no se toca su receta. */
export async function seedPresets(prisma) {
  const ingredients = await prisma.ingredient.findMany({
    select: { id: true, code: true },
  });
  const byCode = Object.fromEntries(ingredients.map((i) => [i.code, i.id]));
  for (const [code, name, description, sortOrder, recipe] of SAMPLE_PRESETS) {
    const existing = await prisma.presetPizza.findUnique({ where: { code } });
    if (existing) continue;
    await prisma.presetPizza.create({
      data: {
        code,
        name,
        description,
        sortOrder,
        active: true,
        ingredients: {
          create: recipe.map(([ingCode, portions]) => ({
            ingredientId: byCode[ingCode],
            portions,
          })),
        },
      },
    });
  }
}

/**
 * Crea (si no existen) 1 administrador y 1 cliente. No cambia la contraseña de un usuario existente.
 * @returns {Array<{email, role, generatedPassword?: string}>} contraseñas generadas (solo si faltaban)
 */
export async function seedUsers(
  prisma,
  { adminEmail, adminPassword, clientEmail, clientPassword, cost = 12 },
) {
  const generated = [];
  const specs = [
    {
      email: adminEmail,
      password: adminPassword,
      role: "ADMIN",
      fullName: "Administrador Good Pizza",
    },
    {
      email: clientEmail,
      password: clientPassword,
      role: "CLIENT",
      fullName: "Cliente de Ejemplo",
    },
  ];
  for (const spec of specs) {
    const email = spec.email.trim().toLowerCase();
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) continue;
    let password = spec.password;
    let wasGenerated = false;
    if (!password) {
      password = crypto.randomBytes(12).toString("base64url");
      wasGenerated = true;
    }
    const role = await prisma.role.findUnique({ where: { code: spec.role } });
    await prisma.user.create({
      data: {
        email,
        fullName: spec.fullName,
        passwordHash: await bcrypt.hash(password, cost),
        roleId: role.id,
      },
    });
    if (wasGenerated)
      generated.push({ email, role: spec.role, generatedPassword: password });
  }
  return generated;
}

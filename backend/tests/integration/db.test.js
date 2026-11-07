// Pruebas de integración con PostgreSQL REAL, SOLO en el esquema `test` (DATABASE_URL_TEST).
// - Se omiten (con aviso) si DATABASE_URL_TEST no está definida.
// - Se abortan si la URL no apunta a ?schema=test o si current_schema() no es `test`.
// - JAMÁS escriben en el esquema `public`.
// Preparación: npm run db:test:migrate
import crypto from "node:crypto";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import request from "supertest";

const TEST_URL = process.env.DATABASE_URL_TEST;
const enabled = Boolean(TEST_URL);

if (!enabled) {
  console.warn(
    "\n[AVISO] DATABASE_URL_TEST no está definida: se OMITEN las pruebas de integración con BD real " +
      "(stock concurrente, secuencia diaria, CHECK, flujo completo). Define DATABASE_URL_TEST en " +
      "backend/.env.local (misma conexión con ?schema=test) y ejecuta npm run db:test:migrate.\n",
  );
}

const API = "/api/v1";
const TABLES = [
  "order_pizza_ingredients",
  "order_pizzas",
  "order_status_history",
  "orders",
  "order_daily_sequences",
  "refresh_tokens",
  "preset_pizza_ingredients",
  "preset_pizzas",
  "ingredient_size_values",
  "ingredients",
  "users",
  "roles",
  "sizes",
  "ingredient_categories",
  "vat_rates",
];

describe.skipIf(!enabled)("Integración con PostgreSQL (esquema test)", () => {
  let prisma;
  let app;
  let ids; // código de ingrediente -> id
  const adminPassword = crypto.randomBytes(12).toString("base64url");
  const adminEmail = "admin@test.local";
  const clientPassword = crypto.randomBytes(12).toString("base64url");
  let admin;
  let clientA;
  let clientB;

  const call = (method, path, token) => {
    const r = request(app)[method](`${API}${path}`);
    return token ? r.set("Authorization", `Bearer ${token}`) : r;
  };
  const login = async (email, password) => {
    const res = await call("post", "/auth/login").send({ email, password });
    expect(res.status).toBe(200);
    return res.body.data;
  };
  const register = async (email) => {
    const res = await call("post", "/auth/register").send({
      fullName: "Cliente Prueba",
      email,
      password: clientPassword,
    });
    expect(res.status).toBe(201);
    return res.body.data;
  };
  const resetStocks = async (value = 100) => {
    await prisma.ingredient.updateMany({
      data: { stock: value, active: true },
    });
  };
  const topping = (code, portions) => ({ ingredientId: ids[code], portions });
  const tripleCheese = (quantity = 1) => ({
    type: "CUSTOM",
    sizeCode: "MEDIUM",
    doughId: ids["MAS-TRA"],
    sauceId: ids["SAL-TOM"],
    toppings: [
      topping("QUE-MOZ", 3),
      topping("CAR-JAM", 1),
      topping("VEG-CHA", 1),
    ],
    quantity,
  });
  const stockOf = async (code) =>
    (await prisma.ingredient.findUnique({ where: { code } })).stock;

  beforeAll(async () => {
    // Barreras de seguridad: nunca operar fuera del esquema `test`.
    const schema = new URL(TEST_URL).searchParams.get("schema");
    if (schema !== "test") {
      throw new Error(
        `DATABASE_URL_TEST debe terminar en ?schema=test (actual: ${schema ?? "ninguno"}). Abortado.`,
      );
    }
    ({ prisma } = await import("../../src/lib/prisma.js"));
    const [{ schema_name }] =
      await prisma.$queryRaw`SELECT current_schema() AS schema_name`;
    if (schema_name !== "test")
      throw new Error(
        `current_schema() es "${schema_name}", no "test". Abortado.`,
      );
    try {
      await prisma.role.count();
    } catch {
      throw new Error(
        "El esquema test no tiene las tablas. Ejecuta: npm run db:test:migrate",
      );
    }

    await prisma.$executeRawUnsafe(
      `TRUNCATE TABLE ${TABLES.map((t) => `"${t}"`).join(", ")} RESTART IDENTITY CASCADE`,
    );
    const { seedReference, seedIngredients, seedPresets, seedUsers } =
      await import("../../prisma/seed-lib.js");
    await seedReference(prisma);
    await seedIngredients(prisma);
    await seedPresets(prisma);
    await seedUsers(prisma, {
      adminEmail,
      adminPassword,
      clientEmail: "cliente@test.local",
      clientPassword,
      cost: 4,
    });
    ids = Object.fromEntries(
      (await prisma.ingredient.findMany()).map((i) => [i.code, i.id]),
    );

    const { createApp } = await import("../../src/app.js");
    app = createApp();
    admin = (await login(adminEmail, adminPassword)).accessToken;
    clientA = await register("clienta@test.local");
    clientB = await register("clientb@test.local");
  });

  afterAll(async () => {
    if (prisma) await prisma.$disconnect();
  });

  it("esquema: existen las 9 restricciones CHECK de la migración", async () => {
    const rows = await prisma.$queryRaw`
      SELECT constraint_name FROM information_schema.check_constraints
      WHERE constraint_schema = 'test' AND constraint_name IN (
        'ingredients_stock_nonneg','isv_price_nonneg','isv_calories_nonneg','vat_rates_percent_range',
        'ppi_portions_range','order_pizzas_quantity_range','opi_portions_range',
        'opi_recipe_portions_range','orders_total_consistent')`;
    expect(rows).toHaveLength(9);
  });

  it("CHECK stock >= 0: PostgreSQL rechaza un stock negativo (última defensa)", async () => {
    await expect(
      prisma.$executeRaw`UPDATE ingredients SET stock = -1 WHERE code = 'QUE-MOZ'`,
    ).rejects.toThrow();
    expect(await stockOf("QUE-MOZ")).toBeGreaterThanOrEqual(0);
  });

  it("GET /health -> 200 con database ok", async () => {
    const res = await call("get", "/health");
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ status: "ok", database: "ok" });
  });

  it("seed: 20 ingredientes, 5 predefinidas, 2 usuarios, y es idempotente", async () => {
    const { seedReference, seedIngredients, seedPresets } =
      await import("../../prisma/seed-lib.js");
    await seedReference(prisma);
    await seedIngredients(prisma);
    await seedPresets(prisma);
    expect(await prisma.ingredient.count()).toBe(20);
    expect(await prisma.presetPizza.count()).toBe(5);
    expect(await prisma.ingredientSizeValue.count()).toBe(60);
    expect(await prisma.vatRate.count()).toBe(2);
  });

  let orderA;

  it("CRITERIO 1: cliente se registra, inicia sesión, personaliza triple queso y obtiene la orden con IVA desglosado", async () => {
    const me = await call("get", "/auth/me", clientA.accessToken);
    expect(me.body.data.role).toBe("CLIENT");

    const list = await call("get", "/ingredients", clientA.accessToken);
    expect(list.body.data).toHaveLength(20);
    expect(list.body.data[0]).toHaveProperty("stock");
    expect(list.body.data[0]).not.toHaveProperty("createdAt");

    const quote = await call("post", "/orders/quote", clientA.accessToken).send(
      { items: [tripleCheese()] },
    );
    expect(quote.status).toBe(200);
    expect(quote.body.data.valid).toBe(true);
    // 15 %: masa 2.00 + queso 3.60 + jamón 1.50 = 7.10 ; 0 %: salsa 1.00 + champiñones 0.90 = 1.90
    expect(quote.body.data.totals).toEqual({
      subtotalVat15: "7.10",
      subtotalVat0: "1.90",
      vat15: "1.07", // 1.065 -> half-up
      total: "10.07",
      totalCalories: 720,
    });

    const res = await call("post", "/orders", clientA.accessToken).send({
      items: [tripleCheese()],
      expectedTotal: "10.07",
    });
    expect(res.status).toBe(201);
    orderA = res.body.data;
    expect(res.headers.location).toBe(`${API}/orders/${orderA.id}`);
    expect(orderA.orderNumber).toMatch(/^GP-\d{8}-0001$/);
    expect(orderA.status).toBe("PENDING");
    expect(orderA.totals.total).toBe("10.07");
    expect(orderA.totals.totalCalories).toBe(720);
    expect(orderA.customer.email).toBe("clienta@test.local");
    expect(
      orderA.pizzas[0].components.find((c) => c.code === "QUE-MOZ"),
    ).toMatchObject({ portions: 3, lineAmount: "3.60" });
    expect(orderA.statusHistory).toHaveLength(1);

    expect(await stockOf("QUE-MOZ")).toBe(397);
    expect(await stockOf("MAS-TRA")).toBe(299);
  });

  it("autorización por dueño: otro cliente recibe 404 y su lista no incluye el pedido; el admin lo ve", async () => {
    expect(
      (await call("get", `/orders/${orderA.id}`, clientB.accessToken)).status,
    ).toBe(404);
    const listB = await call("get", "/orders", clientB.accessToken);
    expect(listB.body).toMatchObject({ data: [], total: 0 });
    const listA = await call("get", "/orders", clientA.accessToken);
    expect(listA.body.total).toBe(1);
    expect(listA.body.data[0]).toMatchObject({
      id: orderA.id,
      pizzaCount: 1,
      total: "10.07",
    });
    expect((await call("get", `/orders/${orderA.id}`, admin)).status).toBe(200);
    const search = await call("get", "/orders?search=clienta@test", admin);
    expect(search.body.total).toBe(1);
  });

  it("el administrador no puede confirmar pedidos (403)", async () => {
    expect(
      (await call("post", "/orders", admin).send({ items: [tripleCheese()] }))
        .status,
    ).toBe(403);
  });

  it("CRITERIOS 2 y 3: el admin cambia precio y stock; el pedido antiguo no cambia; el nuevo usa el precio nuevo", async () => {
    const before = await call("get", `/ingredients/${ids["QUE-MOZ"]}`, admin);
    const body = {
      code: before.body.data.code,
      name: before.body.data.name,
      categoryCode: "CHEESE",
      vatRateCode: "VAT_15",
      sizeValues: before.body.data.sizeValues.map((v) =>
        v.sizeCode === "MEDIUM" ? { ...v, price: "2.00" } : v,
      ),
    };
    const put = await call("put", `/ingredients/${ids["QUE-MOZ"]}`, admin).send(
      body,
    );
    expect(put.status).toBe(200);
    expect(
      put.body.data.sizeValues.find((v) => v.sizeCode === "MEDIUM").price,
    ).toBe("2.00");
    const stock = await call(
      "patch",
      `/ingredients/${ids["QUE-MOZ"]}/stock`,
      admin,
    ).send({ operation: "SET", value: 500 });
    expect(stock.body.data.stock).toBe(500);

    // Pedido antiguo intacto (snapshots)
    const old = await call("get", `/orders/${orderA.id}`, clientA.accessToken);
    expect(old.body.data.totals.total).toBe("10.07");
    expect(
      old.body.data.pizzas[0].components.find((c) => c.code === "QUE-MOZ")
        .unitPrice,
    ).toBe("1.20");

    // Pedido nuevo con el precio nuevo: 2.00 + 6.00 + 1.50 = 9.50 ; vat 1.425 -> 1.43 ; total 9.50 + 1.90 + 1.43 = 12.83
    const quote = await call("post", "/orders/quote", clientA.accessToken).send(
      { items: [tripleCheese()] },
    );
    expect(quote.body.data.totals.total).toBe("12.83");

    // El total esperado desactualizado se rechaza
    const stale = await call("post", "/orders", clientA.accessToken).send({
      items: [tripleCheese()],
      expectedTotal: "10.07",
    });
    expect(stale.status).toBe(409);
    expect(stale.body.error.code).toBe("PRICE_CHANGED");
    expect(stale.body.error.details[0].quote.totals.total).toBe("12.83");
    expect(await stockOf("QUE-MOZ")).toBe(500); // no se descontó nada
  });

  it("CRITERIO 2: el admin avanza el estado hasta Entregado; no hay saltos ni retrocesos; el cliente no puede", async () => {
    expect(
      (
        await call(
          "patch",
          `/orders/${orderA.id}/status`,
          clientA.accessToken,
        ).send({ status: "IN_PREPARATION" })
      ).status,
    ).toBe(403);
    const skip = await call("patch", `/orders/${orderA.id}/status`, admin).send(
      { status: "DELIVERED" },
    );
    expect(skip.status).toBe(422);
    expect(skip.body.error.code).toBe("INVALID_STATUS_TRANSITION");
    const a = await call("patch", `/orders/${orderA.id}/status`, admin).send({
      status: "IN_PREPARATION",
    });
    expect(a.body.data.status).toBe("IN_PREPARATION");
    const b = await call("patch", `/orders/${orderA.id}/status`, admin).send({
      status: "DELIVERED",
    });
    expect(b.body.data.status).toBe("DELIVERED");
    const back = await call("patch", `/orders/${orderA.id}/status`, admin).send(
      { status: "PENDING" },
    );
    expect(back.status).toBe(422);
    const seen = await call("get", `/orders/${orderA.id}`, clientA.accessToken);
    expect(seen.body.data.status).toBe("DELIVERED");
    expect(seen.body.data.statusHistory.map((h) => h.toStatus)).toEqual([
      "PENDING",
      "IN_PREPARATION",
      "DELIVERED",
    ]);
  });

  it("avance concurrente de estado: solo uno de dos PATCH simultáneos tiene éxito", async () => {
    await resetStocks();
    const created = await call("post", "/orders", clientA.accessToken).send({
      items: [tripleCheese()],
    });
    const id = created.body.data.id;
    const results = await Promise.all([
      call("patch", `/orders/${id}/status`, admin).send({
        status: "IN_PREPARATION",
      }),
      call("patch", `/orders/${id}/status`, admin).send({
        status: "IN_PREPARATION",
      }),
    ]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 422]);
    const detail = await call("get", `/orders/${id}`, admin);
    expect(detail.body.data.statusHistory).toHaveLength(2);
  });

  it("IT-B03: 5 confirmaciones simultáneas por stock para 2 pizzas -> exactamente 2 aciertan, 3 reciben 409; sin sobreventa", async () => {
    await resetStocks();
    await prisma.ingredient.update({
      where: { code: "QUE-MOZ" },
      data: { stock: 7 },
    }); // cada pizza pide 3 -> caben 2
    const results = await Promise.all(
      Array.from({ length: 5 }, (_, i) =>
        call(
          "post",
          "/orders",
          i % 2 ? clientA.accessToken : clientB.accessToken,
        ).send({ items: [tripleCheese()] }),
      ),
    );
    const ok = results.filter((r) => r.status === 201);
    const conflict = results.filter((r) => r.status === 409);
    expect(ok).toHaveLength(2);
    expect(conflict).toHaveLength(3);
    for (const r of conflict) {
      expect(r.body.error.code).toBe("INSUFFICIENT_STOCK");
      expect(r.body.error.details[0]).toMatchObject({
        code: "QUE-MOZ",
        requested: 3,
      });
    }
    expect(await stockOf("QUE-MOZ")).toBe(1);
    expect(await stockOf("MAS-TRA")).toBe(98); // solo 2 pedidos descontaron
    // números de orden distintos
    const numbers = ok.map((r) => r.body.data.orderNumber);
    expect(new Set(numbers).size).toBe(2);
  });

  it("secuencia diaria: sin duplicados ni huecos con confirmaciones simultáneas", async () => {
    await resetStocks();
    const before = await prisma.order.count();
    const results = await Promise.all(
      Array.from({ length: 6 }, () =>
        call("post", "/orders", clientA.accessToken).send({
          items: [tripleCheese()],
        }),
      ),
    );
    expect(results.every((r) => r.status === 201)).toBe(true);
    const seq = await prisma.orderDailySequence.findMany();
    expect(seq).toHaveLength(1);
    const total = await prisma.order.count();
    expect(seq[0].lastValue).toBe(total); // sin huecos: el correlativo coincide con el nº de pedidos
    expect(total).toBe(before + 6);
    const numbers = (await prisma.order.findMany()).map((o) => o.orderNumber);
    expect(new Set(numbers).size).toBe(numbers.length);
  });

  it("atomicidad: si un ingrediente no alcanza, NO se descuenta ninguno y el número no se consume", async () => {
    await resetStocks();
    await prisma.ingredient.update({
      where: { code: "VEG-CHA" },
      data: { stock: 0 },
    });
    const seqBefore = (await prisma.orderDailySequence.findFirst()).lastValue;
    const res = await call("post", "/orders", clientA.accessToken).send({
      items: [tripleCheese()],
    });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe("INSUFFICIENT_STOCK");
    expect(res.body.error.message).toContain("Champiñones");
    expect(await stockOf("QUE-MOZ")).toBe(100);
    expect(await stockOf("MAS-TRA")).toBe(100);
    expect((await prisma.orderDailySequence.findFirst()).lastValue).toBe(
      seqBefore,
    );
  });

  it("reglas de armado en confirmación -> 422 y no se descuenta nada", async () => {
    await resetStocks();
    const bad = { ...tripleCheese(), toppings: [topping("QUE-MOZ", 3)] };
    const res = await call("post", "/orders", clientA.accessToken).send({
      items: [bad],
    });
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe("PIZZA_RULES_VIOLATED");
    expect(res.body.error.details[0].code).toBe("MIN_TOPPINGS_NOT_MET");
    const noDough = { ...tripleCheese() };
    delete noDough.doughId;
    const res2 = await call("post", "/orders", clientA.accessToken).send({
      items: [noDough],
    });
    expect(res2.status).toBe(422);
    expect(await stockOf("QUE-MOZ")).toBe(100);
  });

  it("predefinida: precios por fórmula, disponibilidad y pedido con extras (receta + extra cuenta para el máximo)", async () => {
    await resetStocks();
    const list = await call("get", "/preset-pizzas", clientA.accessToken);
    expect(list.body.data).toHaveLength(5);
    const margherita = list.body.data.find((p) => p.code === "MARGHERITA");
    expect(margherita.available).toBe(true);
    expect(margherita.pricesBySize.map((p) => p.sizeCode)).toEqual([
      "INDIVIDUAL",
      "MEDIUM",
      "FAMILY",
    ]);
    // MEDIUM: 2.00 + 1.00 + 2.00 x2 (la mozzarella subió a 2.00 en una prueba anterior) + 0.50 = 7.50
    expect(margherita.pricesBySize[1]).toMatchObject({
      price: "7.50",
      calories: 300 + 60 + 180 + 4,
    });
    expect(margherita.recipe.map((r) => r.code)).toEqual([
      "MAS-TRA",
      "SAL-TOM",
      "VEG-ALB",
      "QUE-MOZ",
    ]);

    const item = (extras) => ({
      type: "PRESET",
      presetPizzaId: margherita.id,
      sizeCode: "MEDIUM",
      extras,
      quantity: 2,
    });
    const tooMany = await call("post", "/orders", clientA.accessToken).send({
      items: [item([topping("QUE-MOZ", 2)])],
    });
    expect(tooMany.status).toBe(422);
    expect(tooMany.body.error.details[0]).toMatchObject({
      code: "MAX_PORTIONS_EXCEEDED",
      meta: { max: 3, requested: 4 },
    });

    const ok = await call("post", "/orders", clientA.accessToken).send({
      items: [item([topping("QUE-MOZ", 1), topping("CAR-JAM", 1)])],
    });
    expect(ok.status).toBe(201);
    const line = ok.body.data.pizzas[0];
    expect(line).toMatchObject({
      type: "PRESET",
      quantity: 2,
      presetPizza: { code: "MARGHERITA", name: "Margarita" },
    });
    expect(line.components.find((c) => c.code === "QUE-MOZ")).toMatchObject({
      portions: 3,
      recipePortions: 2,
    });
    expect(await stockOf("QUE-MOZ")).toBe(100 - 6);
    expect(await stockOf("CAR-JAM")).toBe(100 - 2);
  });

  it("predefinida con ingrediente inactivo = no disponible; no se puede pedir (422 PRESET_UNAVAILABLE)", async () => {
    await resetStocks();
    expect(
      (
        await call(
          "patch",
          `/ingredients/${ids["VEG-ALB"]}/status`,
          admin,
        ).send({ active: false })
      ).status,
    ).toBe(200);
    const list = await call("get", "/preset-pizzas", clientA.accessToken);
    const margherita = list.body.data.find((p) => p.code === "MARGHERITA");
    expect(margherita.available).toBe(false);
    expect(margherita.unavailableReasons[0].code).toBe("PRESET_UNAVAILABLE");
    const order = await call("post", "/orders", clientA.accessToken).send({
      items: [
        {
          type: "PRESET",
          presetPizzaId: margherita.id,
          sizeCode: "MEDIUM",
          extras: [],
          quantity: 1,
        },
      ],
    });
    expect(order.status).toBe(422);
    expect(order.body.error.details[0].code).toBe("PRESET_UNAVAILABLE");
    // el cliente ya no ve el ingrediente inactivo; el admin sí con includeInactive
    expect(
      (await call("get", `/ingredients/${ids["VEG-ALB"]}`, clientA.accessToken))
        .status,
    ).toBe(404);
    expect(
      (await call("get", "/ingredients", clientA.accessToken)).body.data,
    ).toHaveLength(19);
    expect(
      (await call("get", "/ingredients?includeInactive=true", admin)).body.data,
    ).toHaveLength(20);
    await call("patch", `/ingredients/${ids["VEG-ALB"]}/status`, admin).send({
      active: true,
    });
  });

  it("predefinida sin stock para 1 pizza = no disponible", async () => {
    await resetStocks();
    await prisma.ingredient.update({
      where: { code: "QUE-MOZ" },
      data: { stock: 1 },
    });
    const list = await call("get", "/preset-pizzas", clientA.accessToken);
    const margherita = list.body.data.find((p) => p.code === "MARGHERITA"); // pide 2 de mozzarella
    expect(margherita.available).toBe(false);
    expect(margherita.unavailableReasons[0].meta.reason).toBe("OUT_OF_STOCK");
    await resetStocks();
  });

  it("administración de ingredientes: crear, duplicado, tamaños faltantes, categoría bloqueada, ajuste de stock", async () => {
    const sizeValues = [
      { sizeCode: "INDIVIDUAL", price: "1.00", calories: 10 },
      { sizeCode: "MEDIUM", price: "1.50", calories: 20 },
      { sizeCode: "FAMILY", price: "2.20", calories: 30 },
    ];
    const body = {
      code: "nue-001",
      name: "Ingrediente nuevo",
      categoryCode: "OTHER",
      stock: 5,
      sizeValues,
    };
    const created = await call("post", "/ingredients", admin).send(body);
    expect(created.status).toBe(201);
    expect(created.body.data).toMatchObject({
      code: "NUE-001",
      active: true,
      vatRate: { code: "VAT_15", ratePercent: "15.00" },
    });
    expect(
      (await call("post", "/ingredients", admin).send(body)).body.error.code,
    ).toBe("INGREDIENT_CODE_EXISTS");
    const missing = await call("post", "/ingredients", admin).send({
      ...body,
      code: "NUE-002",
      sizeValues: sizeValues.slice(0, 2),
    });
    expect(missing.status).toBe(422);
    expect(missing.body.error).toMatchObject({
      code: "MISSING_SIZE_VALUES",
      details: [{ missing: ["FAMILY"] }],
    });
    const badVat = await call("post", "/ingredients", admin).send({
      ...body,
      code: "NUE-003",
      vatRateCode: "VAT_99",
    });
    expect(badVat.body.error.code).toBe("INVALID_VAT_RATE");

    const locked = await call(
      "put",
      `/ingredients/${ids["MAS-TRA"]}`,
      admin,
    ).send({
      code: "MAS-TRA",
      name: "Masa tradicional",
      categoryCode: "CHEESE",
      sizeValues,
    });
    expect(locked.status).toBe(422);
    expect(locked.body.error.code).toBe("INGREDIENT_CATEGORY_LOCKED");
    expect(locked.body.error.details[0].presetPizzas).toContain("Margarita");

    const id = created.body.data.id;
    expect(
      (
        await call("patch", `/ingredients/${id}/stock`, admin).send({
          operation: "ADD",
          value: -5,
        })
      ).body.data.stock,
    ).toBe(0);
    const neg = await call("patch", `/ingredients/${id}/stock`, admin).send({
      operation: "ADD",
      value: -1,
    });
    expect(neg.status).toBe(422);
    expect(neg.body.error.code).toBe("STOCK_WOULD_BE_NEGATIVE");
    expect(
      (
        await call("patch", `/ingredients/${id}/stock`, admin).send({
          operation: "ADD",
          value: 10,
        })
      ).body.data.stock,
    ).toBe(10);
    expect(
      (
        await call("patch", `/ingredients/${uid404()}/stock`, admin).send({
          operation: "SET",
          value: 1,
        })
      ).status,
    ).toBe(404);
    expect((await call("get", "/vat-rates", admin)).body.data).toHaveLength(2);
    expect((await call("get", "/vat-rates", clientA.accessToken)).status).toBe(
      403,
    );
  });

  it("administración de predefinidas: receta inválida 422, crear, duplicados 409, editar, desactivar", async () => {
    const recipe = [
      { ingredientId: ids["MAS-FIN"], portions: 1 },
      { ingredientId: ids["SAL-BBQ"], portions: 1 },
      { ingredientId: ids["CAR-POL"], portions: 2 },
    ];
    const body = {
      code: "bbq-pollo",
      name: "BBQ Pollo",
      description: "Pollo con salsa BBQ",
      sortOrder: 9,
      recipe,
    };
    const invalid = await call("post", "/preset-pizzas", admin).send({
      ...body,
      recipe: recipe.slice(1),
    });
    expect(invalid.status).toBe(422);
    expect(invalid.body.error.code).toBe("INVALID_RECIPE");
    expect(invalid.body.error.details.map((d) => d.code)).toContain(
      "DOUGH_REQUIRED",
    );

    const created = await call("post", "/preset-pizzas", admin).send(body);
    expect(created.status).toBe(201);
    expect(created.body.data.code).toBe("BBQ-POLLO");
    expect(created.body.data.pricesBySize).toHaveLength(3);
    expect(created.body.data.available).toBe(true);
    expect(
      (await call("post", "/preset-pizzas", admin).send(body)).body.error.code,
    ).toBe("PRESET_CODE_EXISTS");
    expect(
      (
        await call("post", "/preset-pizzas", admin).send({
          ...body,
          code: "OTRO",
        })
      ).body.error.code,
    ).toBe("PRESET_NAME_EXISTS");

    const id = created.body.data.id;
    const edited = await call("put", `/preset-pizzas/${id}`, admin).send({
      ...body,
      name: "BBQ Pollo XL",
      recipe: [...recipe, { ingredientId: ids["VEG-CEB"], portions: 1 }],
    });
    expect(edited.status).toBe(200);
    expect(edited.body.data.name).toBe("BBQ Pollo XL");
    expect(edited.body.data.recipe).toHaveLength(4);

    expect(
      (
        await call("patch", `/preset-pizzas/${id}/status`, admin).send({
          active: false,
        })
      ).body.data.active,
    ).toBe(false);
    const clientList = await call("get", "/preset-pizzas", clientA.accessToken);
    expect(clientList.body.data.some((p) => p.id === id)).toBe(false);
    expect(
      (await call("get", `/preset-pizzas/${id}`, clientA.accessToken)).status,
    ).toBe(404);
    const adminList = await call(
      "get",
      "/preset-pizzas?includeInactive=true",
      admin,
    );
    expect(adminList.body.data.some((p) => p.id === id)).toBe(true);
    expect((await call("get", `/preset-pizzas/${id}`, admin)).status).toBe(200);
  });

  it("autenticación con BD: rotación de refresh y detección de reutilización; logout", async () => {
    const first = await login("cliente@test.local", clientPassword);
    const second = await call("post", "/auth/refresh").send({
      refreshToken: first.refreshToken,
    });
    expect(second.status).toBe(200);
    expect(second.body.data.refreshToken).not.toBe(first.refreshToken);
    const reuse = await call("post", "/auth/refresh").send({
      refreshToken: first.refreshToken,
    });
    expect(reuse.status).toBe(401);
    expect(reuse.body.error.code).toBe("INVALID_REFRESH_TOKEN");
    const afterReuse = await call("post", "/auth/refresh").send({
      refreshToken: second.body.data.refreshToken,
    });
    expect(afterReuse.status).toBe(401); // se revocaron todos los del usuario

    const fresh = await login("cliente@test.local", clientPassword);
    expect(
      (
        await call("post", "/auth/logout").send({
          refreshToken: fresh.refreshToken,
        })
      ).status,
    ).toBe(204);
    expect(
      (
        await call("post", "/auth/logout").send({
          refreshToken: fresh.refreshToken,
        })
      ).status,
    ).toBe(204);
    expect(
      (
        await call("post", "/auth/refresh").send({
          refreshToken: fresh.refreshToken,
        })
      ).status,
    ).toBe(401);
    const hashes = await prisma.refreshToken.findMany({
      where: { tokenHash: fresh.refreshToken },
    });
    expect(hashes).toHaveLength(0); // en BD solo existe el hash, nunca el token
  });

  it("registro duplicado 409 y login incorrecto 401", async () => {
    const dup = await call("post", "/auth/register").send({
      fullName: "Otra",
      email: "CLIENTA@test.local",
      password: clientPassword,
    });
    expect(dup.status).toBe(409);
    expect(dup.body.error.code).toBe("EMAIL_ALREADY_EXISTS");
    const bad = await call("post", "/auth/login").send({
      email: "clienta@test.local",
      password: "incorrecta-123",
    });
    expect(bad.status).toBe(401);
    expect(bad.body.error.code).toBe("INVALID_CREDENTIALS");
  });

  it("catálogos: tamaños y categorías", async () => {
    const sizes = await call("get", "/sizes", clientA.accessToken);
    expect(sizes.body.data.map((s) => s.code)).toEqual([
      "INDIVIDUAL",
      "MEDIUM",
      "FAMILY",
    ]);
    const cats = await call(
      "get",
      "/ingredient-categories",
      clientA.accessToken,
    );
    expect(cats.body.data.map((c) => c.code)).toEqual([
      "DOUGH",
      "SAUCE",
      "CHEESE",
      "MEAT",
      "VEGETABLE",
      "OTHER",
    ]);
  });
});

function uid404() {
  return "00000000-0000-4000-8000-00000000dead";
}

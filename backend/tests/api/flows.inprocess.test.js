// Fase 6 (QA): flujos HTTP de extremo a extremo EN PROCESO. Rutas, middlewares, validación Zod y
// servicios REALES; solo Prisma se sustituye por el doble en memoria (tests/helpers/fakeDb.js).
// No toca ninguna base de datos. La concurrencia real contra PostgreSQL solo se prueba en
// tests/integration/db.test.js (requiere DATABASE_URL_TEST).
import { beforeEach, describe, expect, it, vi } from "vitest";
import request from "supertest";
import { performance } from "node:perf_hooks";

vi.mock("../../src/lib/prisma.js", async () => {
  const { createFakeDb } = await import("../helpers/fakeDb.js");
  return { prisma: createFakeDb() };
});

import { prisma } from "../../src/lib/prisma.js";
import { createApp } from "../../src/app.js";
import { ING, PRESET_MARGHERITA, uid } from "../helpers/catalog.js";
import {
  OTHER_CLIENT_ID,
  adminToken,
  bearer,
  clientToken,
} from "../helpers/tokens.js";

const app = createApp();
const API = "/api/v1";
const admin = () => bearer(adminToken());
const client = () => bearer(clientToken());
const other = () => bearer(clientToken(OTHER_CLIENT_ID));

const tripleCheese = (extra = {}) => ({
  type: "CUSTOM",
  sizeCode: "MEDIUM",
  doughId: ING.dough.id,
  sauceId: ING.sauce.id,
  toppings: [
    { ingredientId: ING.cheese.id, portions: 3 },
    { ingredientId: ING.ham.id, portions: 1 },
    { ingredientId: ING.mushroom.id, portions: 1 },
  ],
  quantity: 1,
  ...extra,
});

const place = (items, headers = client(), body = {}) =>
  request(app)
    .post(`${API}/orders`)
    .set(headers)
    .send({ items, ...body });

const setMediumPrice = (ing, price) => {
  const row = prisma.__state().ingredients.get(ing.id);
  row.sizeValues.find((s) => s.size.code === "MEDIUM").price = price;
};

beforeEach(() => prisma.__reset());

describe("QA-10 / criterio 1, US-11, US-12: confirmar y consultar la orden", () => {
  it("201 con Location, número GP-AAAAMMDD-0001, IVA desglosado y calorías; GET devuelve lo mismo", async () => {
    const res = await place([tripleCheese()]);
    expect(res.status).toBe(201);
    expect(res.headers.location).toBe(`${API}/orders/${res.body.data.id}`);
    expect(res.body.data.orderNumber).toMatch(/^GP-\d{8}-0001$/);
    expect(res.body.data.status).toBe("PENDING");
    expect(res.body.data.totals).toEqual({
      subtotalVat15: "7.70",
      subtotalVat0: "1.60",
      vat15: "1.16",
      total: "10.46",
      totalCalories: 795,
    });
    const got = await request(app)
      .get(`${API}/orders/${res.body.data.id}`)
      .set(client());
    expect(got.status).toBe(200);
    expect(got.body.data).toEqual(res.body.data);
  });

  it("el servidor recalcula: no acepta precios del cliente (campos extra -> 400) y expectedTotal desfasado -> 409", async () => {
    const withPrice = await place([{ ...tripleCheese(), unitPrice: "0.01" }]);
    expect(withPrice.status).toBe(400);
    const stale = await place([tripleCheese()], client(), {
      expectedTotal: "1.00",
    });
    expect(stale.status).toBe(409);
    expect(stale.body.error.code).toBe("PRICE_CHANGED");
    expect(prisma.__state().orders).toHaveLength(0);
  });

  it("descuenta stock y un pedido rechazado por stock no cambia nada (US-11)", async () => {
    await place([tripleCheese({ quantity: 2 })]);
    expect(prisma.__stock(ING.cheese)).toBe(94);
    prisma.__setStock(ING.ham, 1);
    const rejected = await place([tripleCheese({ quantity: 2 })]);
    expect(rejected.status).toBe(409);
    expect(rejected.body.error.code).toBe("INSUFFICIENT_STOCK");
    expect(JSON.stringify(rejected.body.error)).toContain("Jamón");
    expect(prisma.__stock(ING.cheese)).toBe(94);
    expect(prisma.__state().orders).toHaveLength(1);
  });

  it("línea de 21 pizzas -> 400 y de 20 -> 201 (US-09, S-26)", async () => {
    expect((await place([tripleCheese({ quantity: 21 })])).status).toBe(400);
    expect((await place([tripleCheese({ quantity: 20 })])).status).toBe(201);
    expect(prisma.__stock(ING.cheese)).toBe(100 - 60);
  });

  it("personalizada con 2 ingredientes distintos -> 422 PIZZA_RULES_VIOLATED con el mensaje del mínimo (US-04)", async () => {
    const bad = tripleCheese({
      toppings: [
        { ingredientId: ING.cheese.id, portions: 3 },
        { ingredientId: ING.ham.id, portions: 1 },
      ],
    });
    const res = await place([bad]);
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe("PIZZA_RULES_VIOLATED");
    expect(res.body.error.message).toContain(
      "Elige al menos 3 ingredientes distintos",
    );
  });

  it("Margarita (1 topping distinto) se confirma tal cual (S-17) y con una adición (US-08)", async () => {
    const plain = await place([
      {
        type: "PRESET",
        presetPizzaId: PRESET_MARGHERITA.id,
        sizeCode: "MEDIUM",
        extras: [],
        quantity: 1,
      },
    ]);
    expect(plain.status).toBe(201);
    const extra = await place([
      {
        type: "PRESET",
        presetPizzaId: PRESET_MARGHERITA.id,
        sizeCode: "MEDIUM",
        extras: [{ ingredientId: ING.cheese.id, portions: 2 }],
        quantity: 1,
      },
    ]);
    expect(extra.status).toBe(422); // receta 2 + extra 2 = 4 > 3
    expect(extra.body.error.details[0].code).toBe("MAX_PORTIONS_EXCEEDED");
  });
});

describe("QA-11 / criterio 3, US-14: snapshots inmutables ante cambios de precio, calorías, IVA y stock", () => {
  it("tras cambiar precio, calorías y tarifa del queso, el pedido antiguo no cambia y el nuevo usa los valores nuevos", async () => {
    const created = await place([tripleCheese()]);
    const before = (
      await request(app)
        .get(`${API}/orders/${created.body.data.id}`)
        .set(client())
    ).body.data;

    setMediumPrice(ING.cheese, "9.99");
    const row = prisma.__state().ingredients.get(ING.cheese.id);
    row.sizeValues.find((s) => s.size.code === "MEDIUM").calories = 999;
    row.vatRate = { code: "VAT_0", ratePercent: "0.00" };
    row.name = "Queso renombrado";

    const after = (
      await request(app)
        .get(`${API}/orders/${created.body.data.id}`)
        .set(client())
    ).body.data;
    expect(after).toEqual(before);
    expect(after.pizzas[0].components.map((c) => c.name)).toContain(
      "Queso mozzarella",
    );

    const fresh = await place([tripleCheese()]);
    expect(fresh.body.data.totals.total).not.toBe(before.totals.total);
    const cheese = fresh.body.data.pizzas[0].components.find(
      (c) => c.code === "QUE-MOZ",
    );
    expect(cheese).toMatchObject({
      unitPrice: "9.99",
      unitCalories: 999,
      vatRatePercent: "0.00",
    });
  });

  it("pedido antiguo sigue consultable y sin cambios si el ingrediente se desactiva o se agota", async () => {
    const created = await place([tripleCheese()]);
    const before = (
      await request(app)
        .get(`${API}/orders/${created.body.data.id}`)
        .set(client())
    ).body.data;
    prisma.__state().ingredients.get(ING.cheese.id).active = false;
    prisma.__setStock(ING.cheese, 0);
    const after = (
      await request(app)
        .get(`${API}/orders/${created.body.data.id}`)
        .set(admin())
    ).body.data;
    expect(after).toEqual(before);
    const quote = await request(app)
      .post(`${API}/orders/quote`)
      .set(client())
      .send({ items: [tripleCheese()] });
    expect(quote.body.data.valid).toBe(false);
  });
});

describe("QA-12 / US-13, RF-03: autorización por dueño y sin cancelación", () => {
  it("otro cliente recibe 404 por id y no ve el pedido en su lista; el admin lo ve", async () => {
    const created = await place([tripleCheese()]);
    const id = created.body.data.id;
    const foreign = await request(app).get(`${API}/orders/${id}`).set(other());
    expect(foreign.status).toBe(404);
    expect(foreign.body.error.code).toBe("NOT_FOUND");
    const otherList = await request(app).get(`${API}/orders`).set(other());
    expect(otherList.body.total).toBe(0);
    const mine = await request(app).get(`${API}/orders`).set(client());
    expect(mine.body.total).toBe(1);
    expect(mine.body.data[0]).toMatchObject({ id, total: "10.46" });
    const adminList = await request(app).get(`${API}/orders`).set(admin());
    expect(adminList.body.total).toBe(1);
    expect(
      (await request(app).get(`${API}/orders/${id}`).set(admin())).status,
    ).toBe(200);
  });

  it("no hay cancelación: DELETE y /cancel -> 404 ROUTE_NOT_FOUND; PATCH de estado por el cliente -> 403; el pedido sigue Pendiente", async () => {
    const id = (await place([tripleCheese()])).body.data.id;
    for (const [method, path] of [
      ["delete", `${API}/orders/${id}`],
      ["post", `${API}/orders/${id}/cancel`],
      ["put", `${API}/orders/${id}`],
    ]) {
      const res = await request(app)[method](path).set(client()).send({});
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe("ROUTE_NOT_FOUND");
    }
    const patch = await request(app)
      .patch(`${API}/orders/${id}/status`)
      .set(client())
      .send({ status: "IN_PREPARATION" });
    expect(patch.status).toBe(403);
    const still = await request(app).get(`${API}/orders/${id}`).set(client());
    expect(still.body.data.status).toBe("PENDING");
    expect(prisma.__stock(ING.cheese)).toBe(97); // sin devolución de stock
  });

  it("un cliente no puede consultar la lista completa con search (filtro solo ADMIN): solo ve lo suyo", async () => {
    await place([tripleCheese()]);
    await place([tripleCheese()], other());
    const res = await request(app)
      .get(`${API}/orders?search=otro@ejemplo.com`)
      .set(client());
    expect(res.status).toBe(200);
    expect(res.body.data.every((o) => o.customer.id !== OTHER_CLIENT_ID)).toBe(
      true,
    );
  });
});

describe("QA-13 / criterio 2, US-20: el admin avanza el estado y el cliente lo ve", () => {
  it("PENDING -> IN_PREPARATION -> DELIVERED; saltos y retrocesos 422; el cliente ve el nuevo estado", async () => {
    const id = (await place([tripleCheese()])).body.data.id;
    const patch = (status, headers = admin()) =>
      request(app)
        .patch(`${API}/orders/${id}/status`)
        .set(headers)
        .send({ status });

    const skip = await patch("DELIVERED");
    expect(skip.status).toBe(422);
    expect(skip.body.error.code).toBe("INVALID_STATUS_TRANSITION");

    expect((await patch("IN_PREPARATION")).body.data.status).toBe(
      "IN_PREPARATION",
    );
    const seen = await request(app).get(`${API}/orders/${id}`).set(client());
    expect(seen.body.data.status).toBe("IN_PREPARATION");

    expect((await patch("DELIVERED")).body.data.status).toBe("DELIVERED");
    for (const back of ["PENDING", "IN_PREPARATION", "DELIVERED"]) {
      const res = await patch(back);
      expect(res.status).toBe(422);
    }
    const hist = (await request(app).get(`${API}/orders/${id}`).set(client()))
      .body.data.statusHistory;
    expect(hist.map((h) => h.toStatus)).toEqual([
      "PENDING",
      "IN_PREPARATION",
      "DELIVERED",
    ]);
  });

  it("estado inválido -> 400; pedido inexistente -> 404", async () => {
    const bad = await request(app)
      .patch(`${API}/orders/${uid(1)}/status`)
      .set(admin())
      .send({ status: "CANCELLED" });
    expect(bad.status).toBe(400);
    const none = await request(app)
      .patch(`${API}/orders/${uid(4040)}/status`)
      .set(admin())
      .send({ status: "IN_PREPARATION" });
    expect(none.status).toBe(404);
  });
});

describe("QA-14 / US-22, RF-03: matriz de permisos por rol (401 sin token, 403 cliente en rutas ADMIN, 403 admin en POST /orders)", () => {
  const ID = uid(42);
  const adminOnly = [
    ["get", "/vat-rates", undefined],
    ["post", "/ingredients", {}],
    ["put", `/ingredients/${ID}`, {}],
    ["patch", `/ingredients/${ID}/stock`, {}],
    ["patch", `/ingredients/${ID}/status`, {}],
    ["post", "/preset-pizzas", {}],
    ["put", `/preset-pizzas/${ID}`, {}],
    ["patch", `/preset-pizzas/${ID}/status`, {}],
    ["patch", `/orders/${ID}/status`, {}],
  ];
  const authenticated = [
    ["get", "/auth/me"],
    ["get", "/sizes"],
    ["get", "/ingredient-categories"],
    ["get", "/ingredients"],
    ["get", `/ingredients/${ID}`],
    ["get", "/preset-pizzas"],
    ["get", `/preset-pizzas/${ID}`],
    ["post", "/orders/quote"],
    ["post", "/orders"],
    ["get", "/orders"],
    ["get", `/orders/${ID}`],
    ...adminOnly.map(([m, p]) => [m, p]),
  ];

  it.each(adminOnly)(
    "%s %s: CLIENT -> 403 FORBIDDEN",
    async (method, path, body) => {
      const req = request(app)[method](`${API}${path}`).set(client());
      const res = await (body === undefined ? req : req.send(body));
      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe("FORBIDDEN");
    },
  );

  it.each(authenticated)(
    "%s %s: sin token -> 401 UNAUTHENTICATED",
    async (method, path) => {
      const res = await request(app)[method](`${API}${path}`).send({});
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe("UNAUTHENTICATED");
    },
  );

  it("ADMIN no puede confirmar pedidos (403)", async () => {
    const res = await place([tripleCheese()], admin());
    expect(res.status).toBe(403);
    expect(prisma.__state().orders).toHaveLength(0);
  });
});

describe("QA-15 / US-23: health y formato de rutas", () => {
  it("las rutas fuera de /api/v1 responden 404 con el formato de error", async () => {
    const res = await request(app).get("/health");
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe("ROUTE_NOT_FOUND");
  });
});

describe("QA-16 / RNF-01: rendimiento de POST /orders/quote (servicio + motor en proceso, sin BD real)", () => {
  const stats = (samples) => {
    const s = [...samples].sort((a, b) => a - b);
    const at = (p) => s[Math.min(s.length - 1, Math.ceil(p * s.length) - 1)];
    return {
      n: s.length,
      p50: at(0.5),
      p95: at(0.95),
      p99: at(0.99),
      max: s[s.length - 1],
      mean: s.reduce((a, b) => a + b, 0) / s.length,
    };
  };
  const bigOrder = Array.from({ length: 10 }, (_, i) =>
    tripleCheese({
      quantity: 1 + (i % 20),
      sizeCode: ["INDIVIDUAL", "MEDIUM", "FAMILY"][i % 3],
    }),
  );

  it("200 cotizaciones HTTP (Supertest) con 1 y con 10 líneas: p95 < 200 ms", async () => {
    const run = async (items, n) => {
      for (let i = 0; i < 20; i += 1) {
        await request(app)
          .post(`${API}/orders/quote`)
          .set(client())
          .send({ items });
      }
      const times = [];
      for (let i = 0; i < n; i += 1) {
        const t0 = performance.now();
        const res = await request(app)
          .post(`${API}/orders/quote`)
          .set(client())
          .send({ items });
        times.push(performance.now() - t0);
        expect(res.status).toBe(200);
      }
      return stats(times);
    };
    const one = await run([tripleCheese()], 200);
    const ten = await run(bigOrder, 200);
    const fmt = (x) =>
      Object.fromEntries(
        Object.entries(x).map(([k, v]) => [
          k,
          k === "n" ? v : Number(v.toFixed(2)),
        ]),
      );
    console.log("[QA-16] quote 1 línea (ms):", JSON.stringify(fmt(one)));
    console.log("[QA-16] quote 10 líneas (ms):", JSON.stringify(fmt(ten)));
    expect(one.p95).toBeLessThan(200);
    expect(ten.p95).toBeLessThan(200);
  });
});

import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../src/lib/prisma.js", async () => {
  const { createFakeDb } = await import("../helpers/fakeDb.js");
  return { prisma: createFakeDb() };
});

import { prisma } from "../../src/lib/prisma.js";
import * as orderService from "../../src/services/order.service.js";
import {
  ING,
  PRESET_MARGHERITA,
  custom,
  preset,
  uid,
} from "../helpers/catalog.js";
import { ADMIN_ID, CLIENT_ID, OTHER_CLIENT_ID } from "../helpers/tokens.js";
import { localDateString } from "../../src/utils/dates.js";

const three = (extra) =>
  custom(
    [
      [ING.cheese, 3],
      [ING.ham, 1],
      [ING.mushroom, 1],
    ],
    extra,
  );

const rejection = async (promise) => {
  try {
    await promise;
  } catch (e) {
    return e;
  }
  throw new Error("Se esperaba un rechazo");
};

beforeEach(() => prisma.__reset());

describe("order.service.create: confirmación transaccional (RF-18, RF-19, RF-20)", () => {
  it("crea el pedido PENDING con número GP-AAAAMMDD-0001, snapshots e historial", async () => {
    const detail = await orderService.create(CLIENT_ID, { items: [three()] });
    const ymd = localDateString().replaceAll("-", "");
    expect(detail.orderNumber).toBe(`GP-${ymd}-0001`);
    expect(detail.status).toBe("PENDING");
    expect(detail.customer).toEqual({
      id: CLIENT_ID,
      fullName: "Ana Pérez",
      email: "ana@ejemplo.com",
    });
    expect(detail.statusHistory[0]).toMatchObject({
      fromStatus: null,
      toStatus: "PENDING",
    });
    expect(detail.pizzas[0].lineNumber).toBe(1);
    expect(
      detail.pizzas[0].components.map((c) => [c.code, c.portions, c.unitPrice]),
    ).toEqual([
      ["MAS-TRA", 1, "2.00"],
      ["SAL-TOM", 1, "1.00"],
      ["QUE-MOZ", 3, "1.50"],
      ["CAR-JAM", 1, "1.20"],
      ["VEG-CHA", 1, "0.60"],
    ]);
    // 2.00+1.00+4.50+1.20+0.60 = 9.30 ; 0 %: salsa 1.00 + champiñones 0.60 = 1.60 ; 15 %: 7.70
    expect(detail.totals).toEqual({
      subtotalVat15: "7.70",
      subtotalVat0: "1.60",
      vat15: "1.16", // 7.70 x 0.15 = 1.155 -> 1.16 (half-up)
      total: "10.46",
      totalCalories: 300 + 60 + 330 + 90 + 15,
    });
  });

  it("descuenta stock: masa y salsa 1 por pizza, toppings 1 por porción, x cantidad", async () => {
    await orderService.create(CLIENT_ID, { items: [three({ quantity: 2 })] });
    expect(prisma.__stock(ING.dough)).toBe(100 - 2);
    expect(prisma.__stock(ING.sauce)).toBe(100 - 2);
    expect(prisma.__stock(ING.cheese)).toBe(100 - 6);
    expect(prisma.__stock(ING.ham)).toBe(100 - 2);
    expect(prisma.__stock(ING.mushroom)).toBe(100 - 2);
    expect(prisma.__stock(ING.olives)).toBe(100); // no usado
  });

  it("agrega la masa compartida entre líneas (predefinida + personalizada)", async () => {
    await orderService.create(CLIENT_ID, {
      items: [preset([], { quantity: 2 }), three()],
    });
    expect(prisma.__stock(ING.dough)).toBe(100 - 3);
    expect(prisma.__stock(ING.cheese)).toBe(100 - 4 - 3); // receta 2 x2 + 3
  });

  it("bloquea FOR UPDATE con ids ordenados ANTES de descontar y numera dentro de la misma transacción", async () => {
    await orderService.create(CLIENT_ID, { items: [three()] });
    const kinds = prisma.__log.map((l) => l[0]);
    expect(kinds[0]).toBe("lock");
    const lockedIds = prisma.__log[0][1];
    expect(lockedIds).toEqual([...lockedIds].sort());
    expect(kinds.indexOf("lock")).toBeLessThan(kinds.indexOf("updateMany"));
    expect(kinds.indexOf("updateMany")).toBeLessThan(kinds.indexOf("sequence"));
    expect(kinds.indexOf("sequence")).toBeLessThan(
      kinds.indexOf("orderCreate"),
    );
    // los UPDATE de stock salen en orden de id
    const updated = prisma.__log
      .filter((l) => l[0] === "updateMany")
      .map((l) => l[1]);
    expect(updated).toEqual([...updated].sort());
  });

  it("el correlativo avanza por pedido (0001, 0002)", async () => {
    const a = await orderService.create(CLIENT_ID, { items: [three()] });
    const b = await orderService.create(CLIENT_ID, { items: [three()] });
    expect(a.orderNumber.endsWith("-0001")).toBe(true);
    expect(b.orderNumber.endsWith("-0002")).toBe(true);
  });

  it("stock insuficiente -> 409 INSUFFICIENT_STOCK con detalle y SIN cambios (ni stock, ni pedido, ni número)", async () => {
    prisma.__setStock(ING.cheese, 4);
    const err = await rejection(
      orderService.create(CLIENT_ID, { items: [three({ quantity: 2 })] }),
    );
    expect(err).toMatchObject({ status: 409, code: "INSUFFICIENT_STOCK" });
    expect(err.message).toContain("Queso mozzarella");
    expect(err.message).toContain("solicitado 6, disponible 4");
    expect(err.details).toEqual([
      {
        ingredientId: ING.cheese.id,
        code: "QUE-MOZ",
        name: "Queso mozzarella",
        requested: 6,
        available: 4,
      },
    ]);
    expect(prisma.__stock(ING.dough)).toBe(100);
    expect(prisma.__stock(ING.cheese)).toBe(4);
    expect(prisma.__state().orders).toHaveLength(0);
    expect(prisma.__state().sequences.size).toBe(0);
  });

  it("UT-B08: si falla el descuento del 2.º ingrediente, el 1.º se revierte (rollback)", async () => {
    prisma.__failUpdateFor(ING.cheese); // simula la carrera: otro pedido se llevó el stock
    const err = await rejection(
      orderService.create(CLIENT_ID, { items: [three()] }),
    );
    expect(err.code).toBe("INSUFFICIENT_STOCK");
    expect(prisma.__log.at(-1)).toEqual(["rollback"]);
    expect(
      prisma.__log.filter((l) => l[0] === "updateMany").length,
    ).toBeGreaterThan(1); // alguno ya se había descontado
    for (const ing of [
      ING.dough,
      ING.sauce,
      ING.cheese,
      ING.ham,
      ING.mushroom,
    ]) {
      expect(prisma.__stock(ing)).toBe(100);
    }
    expect(prisma.__state().orders).toHaveLength(0);
  });

  it("la violación del CHECK stock >= 0 de PostgreSQL se traduce a 409 INSUFFICIENT_STOCK", async () => {
    prisma.__throwOnUpdate(
      Object.assign(
        new Error('violates check constraint "ingredients_stock_nonneg"'),
        { code: "P2004" },
      ),
    );
    const err = await rejection(
      orderService.create(CLIENT_ID, { items: [three()] }),
    );
    expect(err).toMatchObject({ status: 409, code: "INSUFFICIENT_STOCK" });
  });

  it("reglas de armado incumplidas -> 422 PIZZA_RULES_VIOLATED con violaciones y sin descontar", async () => {
    const err = await rejection(
      orderService.create(CLIENT_ID, { items: [custom([[ING.cheese, 3]])] }),
    );
    expect(err).toMatchObject({ status: 422, code: "PIZZA_RULES_VIOLATED" });
    expect(err.details[0]).toMatchObject({
      code: "MIN_TOPPINGS_NOT_MET",
      itemIndex: 0,
    });
    expect(prisma.__stock(ING.dough)).toBe(100);
    expect(prisma.__log.some((l) => l[0] === "updateMany")).toBe(false);
  });

  it("falta masa -> 422 (en POST /orders doughId ausente produce 422, no 400)", async () => {
    const err = await rejection(
      orderService.create(CLIENT_ID, {
        items: [three({ doughId: undefined })],
      }),
    );
    expect(err.code).toBe("PIZZA_RULES_VIOLATED");
    expect(err.details.map((d) => d.code)).toContain("DOUGH_REQUIRED");
  });

  it("expectedTotal distinto -> 409 PRICE_CHANGED con la cotización nueva y sin crear nada", async () => {
    const err = await rejection(
      orderService.create(CLIENT_ID, {
        items: [three()],
        expectedTotal: "1.00",
      }),
    );
    expect(err).toMatchObject({ status: 409, code: "PRICE_CHANGED" });
    expect(err.details[0].quote.totals.total).toBe("10.46");
    expect(err.details[0].quote.items).toHaveLength(1);
    expect(prisma.__state().orders).toHaveLength(0);
    expect(prisma.__stock(ING.dough)).toBe(100);
  });

  it("expectedTotal igual (aunque sin ceros finales) permite confirmar", async () => {
    const detail = await orderService.create(CLIENT_ID, {
      items: [three()],
      expectedTotal: "10.46",
    });
    expect(detail.total).toBe("10.46");
  });

  it("usuario desactivado -> 403 FORBIDDEN", async () => {
    prisma.__state().users.get(CLIENT_ID).active = false;
    const err = await rejection(
      orderService.create(CLIENT_ID, { items: [three()] }),
    );
    expect(err).toMatchObject({ status: 403, code: "FORBIDDEN" });
  });

  it("predefinida con extras guarda recipePortions y porciones totales (snapshot)", async () => {
    const detail = await orderService.create(CLIENT_ID, {
      items: [preset([[ING.cheese, 1]])],
    });
    const cheese = detail.pizzas[0].components.find(
      (c) => c.code === "QUE-MOZ",
    );
    expect(cheese).toMatchObject({ portions: 3, recipePortions: 2 });
    expect(detail.pizzas[0].type).toBe("PRESET");
    expect(detail.pizzas[0].presetPizza).toMatchObject({
      id: PRESET_MARGHERITA.id,
      name: "Margarita",
    });
  });
});

describe("order.service: consulta y autorización por dueño (RF-22, US-13)", () => {
  it("un cliente ve su pedido; el de otro cliente responde 404 NOT_FOUND", async () => {
    const created = await orderService.create(CLIENT_ID, { items: [three()] });
    const own = await orderService.getById(
      { id: CLIENT_ID, role: "CLIENT" },
      created.id,
    );
    expect(own.id).toBe(created.id);
    const err = await rejection(
      orderService.getById({ id: OTHER_CLIENT_ID, role: "CLIENT" }, created.id),
    );
    expect(err).toMatchObject({ status: 404, code: "NOT_FOUND" });
  });
  it("el administrador ve cualquier pedido", async () => {
    const created = await orderService.create(CLIENT_ID, { items: [three()] });
    const detail = await orderService.getById(
      { id: ADMIN_ID, role: "ADMIN" },
      created.id,
    );
    expect(detail.orderNumber).toBe(created.orderNumber);
  });
  it("listar: el cliente solo recibe sus pedidos; el administrador todos", async () => {
    await orderService.create(CLIENT_ID, { items: [three()] });
    await orderService.create(OTHER_CLIENT_ID, { items: [three()] });
    const mine = await orderService.list({ id: CLIENT_ID, role: "CLIENT" }, {});
    expect(mine).toMatchObject({ page: 1, pageSize: 20, total: 1 });
    expect(mine.data[0].customer.id).toBe(CLIENT_ID);
    const all = await orderService.list({ id: ADMIN_ID, role: "ADMIN" }, {});
    expect(all.total).toBe(2);
  });
});

describe("order.service.updateStatus (RF-21)", () => {
  const admin = ADMIN_ID;
  const make = () => orderService.create(CLIENT_ID, { items: [three()] });

  it("PENDING -> IN_PREPARATION -> DELIVERED y registra el historial", async () => {
    const o = await make();
    const a = await orderService.updateStatus(admin, o.id, "IN_PREPARATION");
    expect(a.status).toBe("IN_PREPARATION");
    const b = await orderService.updateStatus(admin, o.id, "DELIVERED");
    expect(b.status).toBe("DELIVERED");
    expect(b.statusHistory.map((h) => [h.fromStatus, h.toStatus])).toEqual([
      [null, "PENDING"],
      ["PENDING", "IN_PREPARATION"],
      ["IN_PREPARATION", "DELIVERED"],
    ]);
    expect(b.statusHistory[1].changedBy.id).toBe(admin);
  });
  it("salto de estado -> 422 INVALID_STATUS_TRANSITION", async () => {
    const o = await make();
    const err = await rejection(
      orderService.updateStatus(admin, o.id, "DELIVERED"),
    );
    expect(err).toMatchObject({
      status: 422,
      code: "INVALID_STATUS_TRANSITION",
    });
    expect(err.details).toEqual([
      { from: "PENDING", to: "DELIVERED", allowed: ["IN_PREPARATION"] },
    ]);
  });
  it("IT-B02: retroceso DELIVERED -> PENDING -> 422", async () => {
    const o = await make();
    await orderService.updateStatus(admin, o.id, "IN_PREPARATION");
    await orderService.updateStatus(admin, o.id, "DELIVERED");
    const err = await rejection(
      orderService.updateStatus(admin, o.id, "PENDING"),
    );
    expect(err.code).toBe("INVALID_STATUS_TRANSITION");
    expect(err.details[0].allowed).toEqual([]);
  });
  it("pedido inexistente -> 404", async () => {
    const err = await rejection(
      orderService.updateStatus(admin, uid(1234), "IN_PREPARATION"),
    );
    expect(err.code).toBe("NOT_FOUND");
  });
});

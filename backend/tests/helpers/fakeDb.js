// Doble en memoria de lo que usa order.service (Prisma). Modela commit/rollback de $transaction:
// si el callback lanza, el estado vuelve al anterior (sin cambios parciales).
import { ING, PRESET_MARGHERITA, uid } from "./catalog.js";

const clone = (o) => structuredClone(o);

const SORT = { INDIVIDUAL: 1, MEDIUM: 2, FAMILY: 3 };
const CATEGORY_NAMES = {
  DOUGH: "Masa",
  SAUCE: "Salsa",
  CHEESE: "Queso",
  MEAT: "Carne",
  VEGETABLE: "Vegetal",
  OTHER: "Otros",
};

export const ingredientRow = (ing) => ({
  id: ing.id,
  code: ing.code,
  name: ing.name,
  active: ing.active,
  stock: ing.stock,
  category: { code: ing.categoryCode, name: CATEGORY_NAMES[ing.categoryCode] },
  vatRate: {
    code: ing.vatRatePercent === "0.00" ? "VAT_0" : "VAT_15",
    ratePercent: ing.vatRatePercent,
  },
  sizeValues: Object.entries(ing.sizeValues).map(([code, v]) => ({
    size: { code, sortOrder: SORT[code] },
    price: v.price,
    calories: v.calories,
  })),
});

export function createFakeDb() {
  let state;
  const log = [];
  let failUpdateFor = new Set();
  let throwOnUpdate = null;

  const initial = () => ({
    ingredients: new Map(
      Object.values(ING).map((i) => [i.id, clone(ingredientRow(i))]),
    ),
    presets: new Map([
      [
        PRESET_MARGHERITA.id,
        {
          id: PRESET_MARGHERITA.id,
          code: PRESET_MARGHERITA.code,
          name: PRESET_MARGHERITA.name,
          active: true,
          ingredients: PRESET_MARGHERITA.recipe.map((r) => ({ ...r })),
        },
      ],
    ]),
    sizes: [
      { id: 1, code: "INDIVIDUAL", name: "Individual" },
      { id: 2, code: "MEDIUM", name: "Mediana" },
      { id: 3, code: "FAMILY", name: "Familiar" },
    ],
    users: new Map([
      [
        uid(9002),
        {
          id: uid(9002),
          fullName: "Ana Pérez",
          email: "ana@ejemplo.com",
          active: true,
        },
      ],
      [
        uid(9003),
        {
          id: uid(9003),
          fullName: "Otro Cliente",
          email: "otro@ejemplo.com",
          active: true,
        },
      ],
      [
        uid(9001),
        {
          id: uid(9001),
          fullName: "Admin",
          email: "admin@ejemplo.com",
          active: true,
        },
      ],
    ]),
    orders: [],
    sequences: new Map(),
  });
  state = initial();

  const matchWhere = (row, where = {}) =>
    Object.entries(where).every(([k, v]) => {
      if (v && typeof v === "object" && "in" in v) return v.in.includes(row[k]);
      if (v && typeof v === "object" && "gte" in v) return row[k] >= v.gte;
      return row[k] === v;
    });

  const orderShape = (o) => ({ ...o, pizzas: o.pizzas.map((p) => ({ ...p })) });

  function makeApi(s) {
    return {
      user: { findUnique: async ({ where }) => s.users.get(where.id) ?? null },
      presetPizza: {
        findMany: async ({ where }) =>
          [...s.presets.values()].filter((p) => matchWhere(p, where)),
      },
      size: { findMany: async () => s.sizes },
      ingredient: {
        findMany: async ({ where }) =>
          [...s.ingredients.values()].filter((i) => matchWhere(i, where)),
        updateMany: async ({ where, data }) => {
          log.push(["updateMany", where.id]);
          if (throwOnUpdate) throw throwOnUpdate;
          const row = s.ingredients.get(where.id);
          if (
            !row ||
            failUpdateFor.has(where.id) ||
            !matchWhere(row, { stock: where.stock })
          )
            return { count: 0 };
          row.stock -= data.stock.decrement;
          return { count: 1 };
        },
      },
      $queryRaw: async (strings, ...values) => {
        const sql = strings.join("?");
        if (sql.includes("FOR UPDATE")) {
          log.push(["lock", values[0]]);
          return [];
        }
        log.push(["sequence", values[0]]);
        const next = (s.sequences.get(values[0]) ?? 0) + 1;
        s.sequences.set(values[0], next);
        return [{ last_value: next }];
      },
      order: {
        create: async ({ data }) => {
          log.push(["orderCreate"]);
          const id = uid(5000 + s.orders.length + 1);
          const now = new Date();
          const order = {
            ...data,
            id,
            createdAt: now,
            statusChangedAt: now,
            pizzas: data.pizzas.create.map((p, i) => ({
              ...p,
              id: uid(6000 + i),
              presetPizza: p.presetPizzaId
                ? { id: p.presetPizzaId, code: "MARGHERITA" }
                : null,
              ingredients: p.ingredients.create.map((c, j) => ({
                ...c,
                id: uid(7000 + j),
              })),
            })),
            statusHistory: [
              {
                ...data.statusHistory.create,
                changedAt: now,
                changedBy: {
                  id: data.userId,
                  fullName: s.users.get(data.userId).fullName,
                },
              },
            ],
          };
          s.orders.push(order);
          return { id };
        },
        findUnique: async ({ where }) => {
          const o = s.orders.find((x) => x.id === where.id);
          return o ? orderShape(o) : null;
        },
        findFirst: async ({ where }) => {
          const o = s.orders.find((x) => matchWhere(x, where));
          return o ? orderShape(o) : null;
        },
        count: async ({ where }) =>
          s.orders.filter((x) => matchWhere(x, where)).length,
        findMany: async ({ where, skip = 0, take = 20 }) =>
          s.orders
            .filter((x) => matchWhere(x, where))
            .slice(skip, skip + take)
            .map(orderShape),
        updateMany: async ({ where, data }) => {
          const o = s.orders.find(
            (x) => x.id === where.id && x.status === where.status,
          );
          if (!o) return { count: 0 };
          Object.assign(o, data);
          return { count: 1 };
        },
      },
      orderStatusHistory: {
        create: async ({ data }) => {
          const o = s.orders.find((x) => x.id === data.orderId);
          o.statusHistory.push({
            fromStatus: data.fromStatus,
            toStatus: data.toStatus,
            changedAt: new Date(),
            changedBy: {
              id: data.changedById,
              fullName: s.users.get(data.changedById).fullName,
            },
          });
          return {};
        },
      },
    };
  }

  const api = {
    ...makeApi({
      get ingredients() {
        return state.ingredients;
      },
      get presets() {
        return state.presets;
      },
      get sizes() {
        return state.sizes;
      },
      get users() {
        return state.users;
      },
      get orders() {
        return state.orders;
      },
      get sequences() {
        return state.sequences;
      },
    }),
    $transaction: async (fn) => {
      const working = clone(state);
      try {
        const result = await fn(makeApi(working));
        state = working; // commit
        return result;
      } catch (err) {
        log.push(["rollback"]);
        throw err; // el estado anterior permanece intacto
      }
    },
    // utilidades de prueba
    __reset() {
      state = initial();
      log.length = 0;
      failUpdateFor = new Set();
      throwOnUpdate = null;
    },
    __state: () => state,
    __log: log,
    __setStock: (ing, stock) => {
      state.ingredients.get(ing.id).stock = stock;
    },
    __failUpdateFor: (ing) => failUpdateFor.add(ing.id),
    __throwOnUpdate: (err) => {
      throwOnUpdate = err;
    },
    __stock: (ing) => state.ingredients.get(ing.id).stock,
  };
  return api;
}

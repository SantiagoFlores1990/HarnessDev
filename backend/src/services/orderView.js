import { money } from "../utils/money.js";
import { dateToDateOnly, toIso } from "../utils/dates.js";

/**
 * Include de Prisma para armar OrderSummary / OrderDetail solo con snapshots (RF-19).
 */
export const ORDER_DETAIL_INCLUDE = {
  pizzas: {
    orderBy: { lineNumber: "asc" },
    include: {
      presetPizza: { select: { id: true, code: true } },
      ingredients: {
        orderBy: [{ component: "asc" }, { ingredientNameSnapshot: "asc" }],
      },
    },
  },
  statusHistory: {
    orderBy: { changedAt: "asc" },
    include: { changedBy: { select: { id: true, fullName: true } } },
  },
};

export const ORDER_SUMMARY_INCLUDE = { pizzas: { select: { quantity: true } } };

export function toOrderSummary(order) {
  return {
    id: order.id,
    orderNumber: order.orderNumber,
    orderDate: dateToDateOnly(order.orderDate),
    createdAt: toIso(order.createdAt),
    status: order.status,
    customer: {
      id: order.userId,
      fullName: order.customerNameSnapshot,
      email: order.customerEmailSnapshot,
    },
    pizzaCount: order.pizzas.reduce((acc, p) => acc + p.quantity, 0),
    totalCalories: order.totalCalories,
    total: money(order.total),
  };
}

const toComponent = (c) => ({
  ingredientId: c.ingredientId,
  code: c.ingredientCodeSnapshot,
  name: c.ingredientNameSnapshot,
  component: c.component,
  categoryCode: c.categoryCodeSnapshot,
  recipePortions: c.recipePortions,
  portions: c.portions,
  unitPrice: money(c.unitPrice),
  unitCalories: c.unitCalories,
  vatRatePercent: money(c.vatRatePercent),
  lineAmount: money(c.lineAmount),
  lineCalories: c.lineCalories,
});

const toPizza = (p) => ({
  lineNumber: p.lineNumber,
  type: p.kind,
  presetPizza:
    p.kind === "PRESET"
      ? {
          id: p.presetPizzaId ?? null,
          code: p.presetPizza?.code ?? null,
          name: p.presetNameSnapshot,
        }
      : null,
  size: { code: p.sizeCodeSnapshot, name: p.sizeNameSnapshot },
  quantity: p.quantity,
  components: p.ingredients.map(toComponent),
  unitPrice: money(p.unitPrice),
  unitCalories: p.unitCalories,
  unitSubtotalVat15: money(p.unitSubtotalVat15),
  unitSubtotalVat0: money(p.unitSubtotalVat0),
  lineSubtotal: money(p.lineSubtotal),
  lineCalories: p.lineCalories,
});

export function toOrderDetail(order) {
  return {
    ...toOrderSummary(order),
    statusChangedAt: toIso(order.statusChangedAt),
    pizzas: order.pizzas.map(toPizza),
    totals: {
      subtotalVat15: money(order.subtotalVat15),
      subtotalVat0: money(order.subtotalVat0),
      vat15: money(order.vat15Amount),
      total: money(order.total),
      totalCalories: order.totalCalories,
    },
    statusHistory: order.statusHistory.map((h) => ({
      fromStatus: h.fromStatus ?? null,
      toStatus: h.toStatus,
      changedAt: toIso(h.changedAt),
      changedBy: { id: h.changedBy.id, fullName: h.changedBy.fullName },
    })),
  };
}

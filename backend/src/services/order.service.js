import { prisma } from "../lib/prisma.js";
import { AppError, forbidden, notFound } from "../utils/AppError.js";
import { dec } from "../utils/money.js";
import { dateOnlyToDate, localDateString } from "../utils/dates.js";
import { ROLES, STATUS_TRANSITIONS } from "../config/constants.js";
import { quoteOrder } from "./pricing-engine/index.js";
import { loadCatalogForItems } from "./catalogLoader.service.js";
import {
  deductStock,
  insufficientStockError,
  isStockCheckViolation,
} from "./stock.service.js";
import { nextOrderNumber } from "./orderNumber.service.js";
import {
  ORDER_DETAIL_INCLUDE,
  ORDER_SUMMARY_INCLUDE,
  toOrderDetail,
  toOrderSummary,
} from "./orderView.js";

const TX_OPTIONS = { maxWait: 5000, timeout: 10000 };

function shortagesOf(violations) {
  return violations.map((v) => ({
    ingredientId: v.ingredientId,
    code: v.meta.code,
    name: v.meta.name,
    requested: v.meta.requested,
    available: v.meta.available,
  }));
}

/**
 * Confirma un pedido (solo CLIENT, validado en la ruta) en UNA transacción (ADR-004/005):
 * bloqueo FOR UPDATE -> motor -> stock -> número de orden -> pedido con snapshots + historial.
 */
export async function create(userId, { items, expectedTotal }) {
  try {
    const id = await prisma.$transaction(async (tx) => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user || !user.active)
        throw forbidden("Tu cuenta no puede realizar pedidos.");

      const catalog = await loadCatalogForItems(tx, items, { lock: true });
      const quote = quoteOrder(items, catalog);

      const ruleViolations = quote.items.flatMap((i) => i.violations);
      if (ruleViolations.length) {
        throw new AppError(
          422,
          "PIZZA_RULES_VIOLATED",
          `El pedido no cumple las reglas de armado: ${ruleViolations[0].message}`,
          ruleViolations,
        );
      }
      if (quote.violations.length)
        throw insufficientStockError(shortagesOf(quote.violations));
      if (
        expectedTotal !== undefined &&
        !dec(expectedTotal).eq(quote.totals.total)
      ) {
        throw new AppError(
          409,
          "PRICE_CHANGED",
          `El total cambió: ahora es ${quote.totals.total}. Revisa el pedido y confirma de nuevo.`,
          [{ quote: { items: quote.items, totals: quote.totals } }],
        );
      }

      await deductStock(tx, quote.requirements);

      const ymd = localDateString();
      const orderNumber = await nextOrderNumber(tx, ymd);
      const order = await tx.order.create({
        data: {
          orderNumber,
          orderDate: dateOnlyToDate(ymd),
          userId: user.id,
          customerNameSnapshot: user.fullName,
          customerEmailSnapshot: user.email,
          status: "PENDING",
          subtotalVat15: quote.totals.subtotalVat15,
          subtotalVat0: quote.totals.subtotalVat0,
          vat15Amount: quote.totals.vat15,
          total: quote.totals.total,
          totalCalories: quote.totals.totalCalories,
          pizzas: {
            create: quote.items.map((p, i) => ({
              lineNumber: i + 1,
              kind: p.type,
              presetPizzaId:
                p.type === "PRESET" ? items[i].presetPizzaId : null,
              presetNameSnapshot: p.presetPizza?.name ?? null,
              sizeId: catalog.sizes[p.size.code].id,
              sizeCodeSnapshot: p.size.code,
              sizeNameSnapshot: p.size.name,
              quantity: p.quantity,
              unitPrice: p.unitPrice,
              unitCalories: p.unitCalories,
              unitSubtotalVat15: p.unitSubtotalVat15,
              unitSubtotalVat0: p.unitSubtotalVat0,
              lineSubtotal: p.lineSubtotal,
              lineCalories: p.lineCalories,
              ingredients: {
                create: p.components.map((c) => ({
                  ingredientId: c.ingredientId,
                  component: c.component,
                  ingredientCodeSnapshot: c.code,
                  ingredientNameSnapshot: c.name,
                  categoryCodeSnapshot: c.categoryCode,
                  recipePortions: c.recipePortions,
                  portions: c.portions,
                  unitPrice: c.unitPrice,
                  unitCalories: c.unitCalories,
                  vatRatePercent: c.vatRatePercent,
                  lineAmount: c.lineAmount,
                  lineCalories: c.lineCalories,
                })),
              },
            })),
          },
          statusHistory: {
            create: {
              fromStatus: null,
              toStatus: "PENDING",
              changedById: user.id,
            },
          },
        },
        select: { id: true },
      });
      return order.id;
    }, TX_OPTIONS);
    const order = await prisma.order.findUnique({
      where: { id },
      include: ORDER_DETAIL_INCLUDE,
    });
    return toOrderDetail(order);
  } catch (err) {
    if (isStockCheckViolation(err)) {
      throw new AppError(
        409,
        "INSUFFICIENT_STOCK",
        "No hay stock suficiente para completar el pedido.",
      );
    }
    throw err;
  }
}

export async function list(user, query) {
  const where = {};
  if (user.role === ROLES.CLIENT) where.userId = user.id; // autorización por dueño
  if (query.status) where.status = query.status;
  if (query.from || query.to) {
    where.orderDate = {};
    if (query.from) where.orderDate.gte = dateOnlyToDate(query.from);
    if (query.to) where.orderDate.lte = dateOnlyToDate(query.to);
  }
  if (query.search && user.role === ROLES.ADMIN) {
    where.OR = [
      { orderNumber: { contains: query.search, mode: "insensitive" } },
      {
        customerEmailSnapshot: { contains: query.search, mode: "insensitive" },
      },
    ];
  }
  const page = query.page ?? 1;
  const pageSize = query.pageSize ?? 20;
  const [total, rows] = await Promise.all([
    prisma.order.count({ where }),
    prisma.order.findMany({
      where,
      orderBy: { createdAt: "desc" },
      include: ORDER_SUMMARY_INCLUDE,
      skip: (page - 1) * pageSize,
      take: pageSize,
    }),
  ]);
  return { data: rows.map(toOrderSummary), page, pageSize, total };
}

/** Un cliente solo ve sus pedidos; uno ajeno responde 404 (no revela existencia). */
export async function getById(user, id) {
  const where = user.role === ROLES.CLIENT ? { id, userId: user.id } : { id };
  const order = await prisma.order.findFirst({
    where,
    include: ORDER_DETAIL_INCLUDE,
  });
  if (!order) throw notFound("Pedido no encontrado.");
  return toOrderDetail(order);
}

function invalidTransition(from, to) {
  return new AppError(
    422,
    "INVALID_STATUS_TRANSITION",
    "Solo se puede avanzar de Pendiente a En preparación y de En preparación a Entregado.",
    [{ from, to, allowed: STATUS_TRANSITIONS[from] ?? [] }],
  );
}

export async function updateStatus(adminId, id, status) {
  await prisma.$transaction(async (tx) => {
    const order = await tx.order.findUnique({
      where: { id },
      select: { id: true, status: true },
    });
    if (!order) throw notFound("Pedido no encontrado.");
    if (!STATUS_TRANSITIONS[order.status].includes(status))
      throw invalidTransition(order.status, status);
    // UPDATE ... WHERE status = $prev evita dobles avances concurrentes.
    const result = await tx.order.updateMany({
      where: { id, status: order.status },
      data: { status, statusChangedAt: new Date() },
    });
    if (result.count === 0) {
      const now = await tx.order.findUnique({
        where: { id },
        select: { status: true },
      });
      throw invalidTransition(now.status, status);
    }
    await tx.orderStatusHistory.create({
      data: {
        orderId: id,
        fromStatus: order.status,
        toStatus: status,
        changedById: adminId,
      },
    });
  }, TX_OPTIONS);
  const order = await prisma.order.findUnique({
    where: { id },
    include: ORDER_DETAIL_INCLUDE,
  });
  return toOrderDetail(order);
}

import { prisma } from "../lib/prisma.js";
import { quoteOrder } from "./pricing-engine/index.js";
import { loadCatalogForItems } from "./catalogLoader.service.js";

/** Cotización sin escritura: mismo motor que POST /orders (ADR-002). */
export async function quote(items) {
  const catalog = await loadCatalogForItems(prisma, items);
  const {
    valid,
    violations,
    items: priced,
    totals,
    stock,
  } = quoteOrder(items, catalog);
  return { valid, violations, items: priced, totals, stock };
}

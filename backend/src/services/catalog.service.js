import { prisma } from "../lib/prisma.js";
import { money } from "../utils/money.js";

export async function listSizes() {
  const rows = await prisma.size.findMany({ orderBy: { sortOrder: "asc" } });
  return rows.map((s) => ({
    code: s.code,
    name: s.name,
    sortOrder: s.sortOrder,
  }));
}

export async function listCategories() {
  const rows = await prisma.ingredientCategory.findMany({
    orderBy: { sortOrder: "asc" },
  });
  return rows.map((c) => ({
    code: c.code,
    name: c.name,
    sortOrder: c.sortOrder,
  }));
}

export async function listVatRates() {
  const rows = await prisma.vatRate.findMany({
    orderBy: { ratePercent: "desc" },
  });
  return rows.map((v) => ({
    code: v.code,
    name: v.name,
    ratePercent: money(v.ratePercent),
    isDefault: v.isDefault,
  }));
}

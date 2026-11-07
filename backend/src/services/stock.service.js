import { AppError } from "../utils/AppError.js";

/** Error 409 INSUFFICIENT_STOCK con detalle por ingrediente (RNF-06). */
export function insufficientStockError(shortages) {
  const first = shortages[0];
  const extra =
    shortages.length > 1
      ? ` (y ${shortages.length - 1} ingrediente(s) más)`
      : "";
  return new AppError(
    409,
    "INSUFFICIENT_STOCK",
    `No hay stock suficiente de ${first.name}: solicitado ${first.requested}, disponible ${first.available}.${extra}`,
    shortages.map(({ ingredientId, code, name, requested, available }) => ({
      ingredientId,
      code,
      name,
      requested,
      available,
    })),
  );
}

/**
 * Descuenta stock dentro de una transacción ya abierta, por ingrediente y en orden de id:
 * UPDATE ... SET stock = stock - n WHERE id = $id AND stock >= n (se exige 1 fila afectada).
 * @param tx cliente de transacción de Prisma
 * @param requirements [{ ingredientId, code, name, required, available }] ordenado por id
 */
export async function deductStock(tx, requirements) {
  const sorted = [...requirements].sort((a, b) =>
    a.ingredientId < b.ingredientId ? -1 : 1,
  );
  for (const r of sorted) {
    const result = await tx.ingredient.updateMany({
      where: { id: r.ingredientId, stock: { gte: r.required } },
      data: { stock: { decrement: r.required } },
    });
    if (result.count !== 1) {
      throw insufficientStockError([
        {
          ingredientId: r.ingredientId,
          code: r.code,
          name: r.name,
          requested: r.required,
          available: r.available,
        },
      ]);
    }
  }
}

/** ¿El error es la violación de CHECK (stock >= 0)? (última defensa, ADR-005) */
export const isStockCheckViolation = (err) =>
  err?.code === "P2004" ||
  /ingredients_stock_nonneg/.test(String(err?.message ?? ""));

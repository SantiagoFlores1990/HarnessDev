import { formatOrderNumber } from "../utils/orderNumber.js";

/**
 * Siguiente correlativo del día (ADR-004), dentro de la transacción del pedido:
 * la fila queda bloqueada hasta el commit y un rollback también revierte el incremento.
 * @param tx cliente de transacción de Prisma
 * @param ymd fecha de negocio YYYY-MM-DD (zona horaria del servidor)
 */
export async function nextOrderNumber(tx, ymd) {
  const rows = await tx.$queryRaw`
    INSERT INTO order_daily_sequences (order_date, last_value, updated_at)
    VALUES (${ymd}::date, 1, now())
    ON CONFLICT (order_date)
    DO UPDATE SET last_value = order_daily_sequences.last_value + 1, updated_at = now()
    RETURNING last_value`;
  return formatOrderNumber(ymd, Number(rows[0].last_value));
}

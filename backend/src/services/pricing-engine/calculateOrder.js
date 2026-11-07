import { dec, money, sum, vatOf } from "../../utils/money.js";
import { VAT_STANDARD_PERCENT } from "../../config/constants.js";

/**
 * Totales del pedido. El IVA se calcula UNA vez sobre el subtotal 15 % del pedido completo,
 * con redondeo half-up a 2 decimales (S-19, US-10). Total = Sub15 + Sub0 + IVA.
 */
export function calculateOrder(pizzas) {
  const sub15 = sum(
    pizzas.map((p) => dec(p.unitSubtotalVat15).mul(p.quantity)),
  );
  const sub0 = sum(pizzas.map((p) => dec(p.unitSubtotalVat0).mul(p.quantity)));
  const vat15 = vatOf(sub15, VAT_STANDARD_PERCENT);
  return {
    subtotalVat15: money(sub15),
    subtotalVat0: money(sub0),
    vat15: money(vat15),
    total: money(sub15.plus(sub0).plus(vat15)),
    totalCalories: pizzas.reduce((a, p) => a + p.lineCalories, 0),
  };
}

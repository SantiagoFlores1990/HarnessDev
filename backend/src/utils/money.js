import Decimal from 'decimal.js';

// Aritmética decimal exacta; el redondeo del IVA es half-up (ADR-008).
const D = Decimal.clone({ precision: 40, rounding: Decimal.ROUND_HALF_UP });

export const dec = (value) => new D(value === null || value === undefined ? 0 : value.toString());

export const roundHalfUp = (value, places = 2) => dec(value).toDecimalPlaces(places, Decimal.ROUND_HALF_UP);

/** Decimal -> string con exactamente 2 decimales ("7.50"). */
export const money = (value) => roundHalfUp(value, 2).toFixed(2);

/** IVA 15 % de un subtotal: round_half_up(subtotal × 15 / 100, 2). */
export const vatOf = (subtotal, ratePercent = 15) => roundHalfUp(dec(subtotal).mul(ratePercent).div(100), 2);

export const sum = (values) => values.reduce((acc, v) => acc.plus(dec(v)), dec(0));

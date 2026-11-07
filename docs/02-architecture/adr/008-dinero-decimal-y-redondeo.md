# ADR-008: Dinero como Decimal, string en JSON y redondeo half-up del IVA

- **Estado:** Aceptado · **Fecha:** 2026-11-06

## Contexto

Dinero con Decimal, nunca Float (prompt, RNF-02); USD con 2 decimales; IVA calculado sobre cada subtotal y redondeado half-up (S-19, US-10: 0.045 → 0.05). La skill `api-design` pide decidir string decimal o centavos.

## Decisión

- BD: `Decimal(10,2)` precios unitarios, `Decimal(12,2)` totales, `Decimal(5,2)` tarifas.
- Backend: aritmética con `Prisma.Decimal` (decimal.js), función `roundHalfUp(value, 2)` con `Decimal.ROUND_HALF_UP`. Precios de catálogo con exactamente ≤ 2 decimales (validado con Zod), por lo que sumas y productos por enteros son exactos; el único redondeo es el del IVA: `vat15 = roundHalfUp(subtotalVat15 × 15 / 100, 2)`, aplicado una vez sobre el subtotal del pedido completo.
- La tarifa se toma del snapshot de cada componente; el sistema soporta 15 % y 0 % (las tarifas son datos, no constantes).
- JSON: importes como **string** `"7.50"` (siempre 2 decimales); calorías como entero.
- Flutter: muestra los strings formateados (`intl`, USD) y nunca suma importes.

## Alternativas

- **Enteros en centavos:** exactos y simples en JSON, pero obligan a convertir en todas las pantallas y en el admin; la BD ya es Decimal.
- **Number en JSON:** riesgo de flotantes en Dart (`double`).
- **Redondeo por línea:** contradice S-19 / US-10.

## Consecuencias

- (+) Sin errores de coma flotante en ninguna capa.
- (−) Los clientes deben parsear strings (documentado en el contrato).

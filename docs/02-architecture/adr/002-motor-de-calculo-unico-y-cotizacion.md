# ADR-002: Motor de cálculo único en el backend y endpoint de cotización `/orders/quote`

- **Estado:** Aceptado · **Fecha:** 2026-11-06

## Contexto

El cliente debe ver en vivo precio y calorías (RF-13) y las validaciones de armado (RF-09..RF-14). El servidor no puede confiar en el cliente (RNF-04) y debe recalcular al confirmar. Si Flutter implementara las fórmulas, el IVA half-up y las reglas, habría dos implementaciones que pueden divergir (p. ej. el redondeo del IVA sobre el subtotal, S-19, o el conteo receta + extras, RF-14).

## Decisión

1. Un único motor puro en `backend/src/services/pricing-engine/` con: normalización de pizzas CUSTOM/PRESET a componentes (masa, salsa, toppings), validaciones, cálculo de precio/calorías/subtotales por tarifa, totales del pedido con IVA half-up sobre el subtotal 15 % y agregación de stock requerido.
2. `POST /api/v1/orders/quote` expone el motor sin escribir nada; responde 200 con `valid` y `violations` para que la UI muestre mensajes sin tratar 422 como error. Flutter lo invoca con _debounce_ (~150 ms) y cancelación de la petición previa.
3. `POST /api/v1/orders` usa el mismo motor dentro de la transacción y convierte violaciones en `422 PIZZA_RULES_VIOLATED` / `409 INSUFFICIENT_STOCK`.
4. `GET /preset-pizzas` usa el motor para `pricesBySize` (S-18: sin precio fijo).
5. Masa y salsa son componentes con `portions = 1`; los toppings y extras no pueden ser de categoría `DOUGH`/`SAUCE` (interpretación de "exactamente 1 masa y 1 salsa base").

## Alternativas

- **Cálculo en Flutter + recálculo en servidor:** latencia cero, pero reglas duplicadas en Dart y JS; riesgo de que el total mostrado difiera del cobrado.
- **Paquete compartido (p. ej. reglas en JSON/DSL interpretadas en ambos lados):** sobreingeniería para este alcance.
- **Endpoint `/pizzas/quote` separado para una pizza:** se descarta en favor de una sola ruta que acepta 1..N ítems (sirve al armado y al resumen).

## Consecuencias

- (+) Una sola fuente de verdad; las pruebas unitarias del motor cubren lo que ve el cliente y lo que se guarda.
- (+) El frontend es más simple (solo límites de entrada: máx. porciones y cantidad, derivados de datos del servidor).
- (−) Dependencia de red para el cálculo en vivo; en el local (misma máquina/LAN) la latencia esperada es < 50 ms, compatible con RNF-01 (< 200 ms). Si no lo fuera, se mostraría el último valor con indicador de actualización.
- (−) La cotización consume cuota del rate limiter global; el valor por defecto (`RATE_LIMIT_MAX=300`/15 min) y el debounce lo contemplan.

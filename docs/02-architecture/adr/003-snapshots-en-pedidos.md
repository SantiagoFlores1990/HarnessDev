# ADR-003: Snapshots de precios, calorías e IVA en el pedido

- **Estado:** Aceptado · **Fecha:** 2026-11-06

## Contexto

RF-19 y el criterio de aceptación 3 exigen que los pedidos antiguos no cambien cuando cambian precios, calorías, tarifas de IVA, nombres o recetas. RNF-10 pide snapshots inmutables.

## Decisión

Al confirmar se copian al pedido todos los datos necesarios para reconstruir el comprobante sin consultar el catálogo:

- `orders`: nombre y email del cliente, subtotales 15 % / 0 %, IVA, total, calorías totales.
- `order_pizzas`: tipo, nombre de la predefinida, código y nombre del tamaño, cantidad, precio y calorías unitarios, subtotales unitarios por tarifa, subtotal y calorías de la línea.
- `order_pizza_ingredients`: componente (DOUGH/SAUCE/TOPPING), código, nombre y categoría del ingrediente, porciones de receta y totales, precio y calorías unitarios por tamaño, tarifa IVA, importe y calorías de la línea.
  Las FK al catálogo se conservan (con `onDelete: Restrict`, o `SetNull` para la predefinida de origen) solo para trazabilidad; `GET /orders/:id` usa exclusivamente snapshots. No existe endpoint de edición de pedidos.

## Alternativas

- **Versionado del catálogo (tablas históricas de precios con vigencia):** correcto pero más complejo; las consultas del comprobante necesitan _joins_ por fecha.
- **Guardar solo el total:** no permite mostrar el detalle exigido por RF-24.
- **JSON con el comprobante completo en `orders`:** simple, pero se pierde integridad referencial y consultas por ingrediente.

## Consecuencias

- (+) Comprobantes idénticos para siempre; pruebas directas del criterio 3.
- (−) Redundancia de datos (aceptable por volumen de un local).

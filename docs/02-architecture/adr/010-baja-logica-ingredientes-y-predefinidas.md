# ADR-010: Baja lógica de ingredientes y pizzas predefinidas

- **Estado:** Aceptado (predefinidas: pendiente de confirmación, PA-02) · **Fecha:** 2026-11-06

## Contexto

S-23: los ingredientes solo se desactivan, nunca se borran; los pedidos referencian ingredientes (RF-29). El prompt pide "CRUD de pizzas predefinidas" sin precisar el borrado.

## Decisión

- Ingredientes: `active` + `PATCH /ingredients/:id/status`; no existe `DELETE`. FK desde recetas y pedidos con `onDelete: Restrict`.
- Predefinidas: misma estrategia (`active` + `PATCH /preset-pizzas/:id/status`, sin `DELETE`), para conservar la trazabilidad de `order_pizzas.preset_pizza_id` y la simetría con ingredientes. La FK desde pedidos es `SetNull` y el nombre queda en snapshot, de modo que un borrado físico futuro sería posible sin romper pedidos.
- Una predefinida activa con algún ingrediente inactivo o sin stock se muestra como no disponible (S-25).

## Alternativas

- **Borrado físico de predefinidas:** posible gracias a `SetNull` + snapshot, pero pierde la referencia de origen en el histórico.
- **Borrado físico de ingredientes:** prohibido por S-23.

## Consecuencias

- (+) Histórico íntegro y reversible (reactivar).
- (−) La "D" del CRUD de predefinidas es una desactivación; se pide confirmación al usuario (PA-02).

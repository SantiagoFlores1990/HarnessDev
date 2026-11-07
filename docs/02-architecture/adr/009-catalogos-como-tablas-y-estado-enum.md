# ADR-009: Roles, tamaños, categorías y tarifas IVA como tablas; estado del pedido como enum

- **Estado:** Aceptado · **Fecha:** 2026-11-06

## Contexto

El prompt pide en el ER "usuarios y roles, tamaños, categorías, tarifas de IVA" como entidades. El ER conceptual de la fase 1 incluía además `ORDER_STATUS`.

## Decisión

- `roles`, `sizes`, `ingredient_categories`, `vat_rates`: tablas con `code` único estable usado por el código y la API, y `name` en español para la UI. Se cargan por seed; no hay endpoints de escritura (conjuntos fijos en el alcance).
- Estado del pedido: enum PostgreSQL `order_status` (`PENDING`, `IN_PREPARATION`, `DELIVERED`) porque sus transiciones están codificadas en la lógica y no son parametrizables; la trazabilidad se cubre con `order_status_history`.
- Enums técnicos adicionales: `pizza_kind` (PRESET/CUSTOM) y `pizza_component` (DOUGH/SAUCE/TOPPING).

## Alternativas

- **Todo como enums:** menos tablas, pero el prompt pide estas entidades y las tarifas de IVA llevan datos (porcentaje, por defecto).
- **Estado como tabla:** coherente con el ER conceptual, pero añade un _join_ y no aporta parametrización (las transiciones siguen en código).

## Consecuencias

- (+) Cumple el mínimo del prompt y permite nombres visibles editables por migración/seed.
- (−) Desviación menor respecto al ER conceptual (ORDER_STATUS pasa a enum), registrada en `diagrama-er.md`.

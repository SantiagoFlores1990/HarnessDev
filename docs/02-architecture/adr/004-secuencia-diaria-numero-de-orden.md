# ADR-004: Número de orden `GP-AAAAMMDD-NNNN` con secuencia diaria transaccional

- **Estado:** Aceptado · **Fecha:** 2026-11-06

## Contexto

El número tiene formato `GP-AAAAMMDD-0001`, la secuencia reinicia cada día (S-13) y la fecha es la de la zona horaria del servidor (S-24). Dos pedidos concurrentes no pueden recibir el mismo número y un pedido rechazado no debería consumir número (deseable, no exigido).

## Decisión

- Tabla `order_daily_sequences(order_date DATE PK, last_value INT)`.
- Dentro de la misma transacción del pedido, después de validar y descontar stock:
  `INSERT … VALUES ($fecha, 1) ON CONFLICT (order_date) DO UPDATE SET last_value = last_value + 1 RETURNING last_value`.
  La fila queda bloqueada hasta el commit, serializando a los concurrentes del mismo día; si la transacción se revierte, el incremento también.
- `$fecha` se calcula en Node con la fecha local del proceso (zona horaria del SO del servidor) y se guarda en `orders.order_date`.
- Formato: `GP-` + `YYYYMMDD` + `-` + correlativo con `padStart(4, '0')`. Si se superan 9999 pedidos en un día el correlativo crece a 5 dígitos (no se trunca).
- `orders.order_number` tiene índice único como defensa adicional.

## Alternativas

- **`SEQUENCE` de PostgreSQL + reinicio diario por tarea programada:** requiere un _job_ (no hay DevOps) y las secuencias no son transaccionales (huecos ante rollback).
- **`MAX(order_number)+1` del día:** condición de carrera sin bloqueo explícito.
- **Contar pedidos del día:** mismo problema y coste creciente.

## Consecuencias

- (+) Sin huecos ante rollback, sin carreras, sin tareas programadas.
- (−) Serializa la confirmación de pedidos del mismo día (irrelevante para un local).
- (−) Cambiar la zona horaria del servidor alteraría la fecha de negocio (documentado; S-24).

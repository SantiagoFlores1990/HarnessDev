# ADR-005: Descuento de stock transaccional sin sobreventa

- **Estado:** Aceptado · **Fecha:** 2026-11-06

## Contexto

RF-18: al confirmar se descuenta stock (1 por porción; masa y salsa 1 por pizza; × cantidad, S-12) en una transacción; si no alcanza se rechaza con mensaje claro y sin cambios parciales. US-11: dos clientes que compiten por el último stock → solo uno tiene éxito (RNF-02).

## Decisión

En `order.service.create`, dentro de `prisma.$transaction` (Read Committed):

1. Calcular el conjunto de ingredientes implicados (masas, salsas, toppings, recetas de predefinidas y extras).
2. `SELECT id, stock, active, … FROM ingredients WHERE id = ANY($ids) ORDER BY id FOR UPDATE` — bloqueo pesimista en orden determinista para evitar interbloqueos.
3. Ejecutar el motor con los valores **bloqueados** (precios, tarifas y stock coherentes con lo que se va a guardar). Agregar requerimientos por ingrediente entre todas las líneas.
4. Si algún requerido > disponible → `409 INSUFFICIENT_STOCK` con `details` por ingrediente (rollback).
5. `UPDATE ingredients SET stock = stock - $n WHERE id = $id AND stock >= $n` por ingrediente (comprobando 1 fila afectada).
6. Numeración (ADR-004) e inserción del pedido con snapshots (ADR-003). Commit.
   Defensa en profundidad: `CHECK (stock >= 0)` en la tabla; si algo lo violara, PostgreSQL aborta la transacción y el servicio responde `409 INSUFFICIENT_STOCK`.
   Ajustes manuales del admin (`PATCH /ingredients/:id/stock` con `ADD`) usan `stock = stock + value` atómico. Timeout de la transacción interactiva: 10 s.

## Alternativas

- **Solo `UPDATE … WHERE stock >= n` sin `FOR UPDATE`:** también evita sobreventa, pero los precios leídos podrían no corresponder al instante del descuento y los mensajes de error requieren otra lectura.
- **Optimistic locking con columna `version`:** requiere reintentos en el cliente; más complejo para el mismo resultado.
- **Aislamiento `SERIALIZABLE`:** correcto pero obliga a reintentar ante errores de serialización.
- **Reserva de stock al cotizar/agregar al carrito:** no pedido; complica con expiraciones.

## Consecuencias

- (+) Sin sobreventa ni cambios parciales; mensajes precisos (solicitado vs disponible).
- (+) Coherencia entre precio cotizado al confirmar y snapshot guardado.
- (−) El stock mostrado durante el armado es informativo; puede agotarse antes de confirmar (se informa con 409 y la UI recotiza).
- (−) La prueba de concurrencia real requiere una BD de pruebas (ver PA-01).

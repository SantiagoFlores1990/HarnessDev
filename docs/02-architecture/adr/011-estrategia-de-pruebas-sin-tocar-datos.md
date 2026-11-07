# ADR-011: Estrategia de pruebas del backend sin alterar la base `pizzeria`

- **Estado:** Propuesto (depende de PA-01) · **Fecha:** 2026-11-06

## Contexto

El prompt exige Vitest + Supertest con pruebas de cálculo, reglas, stock, endpoints y permisos, y que `npm test` pase. La base `pizzeria` ya existe, contiene los datos de la app y no debe borrarse ni recrearse. `backend/.env.local` no se lee.

## Decisión

- **Unitarias puras** del `pricing-engine` (precio, calorías, IVA 15 %/0 % y half-up, mínimo 3 toppings, máximo 3 porciones, stock agregado, receta + extras) y de utilidades (`money`, formato de número de orden): sin BD.
- **API con Supertest** sobre `app.js`, con `lib/prisma.js` o los servicios sustituidos por dobles (`vi.mock`) y tokens firmados con un secreto de prueba fijado en `vitest.config.js` (`env`), para cubrir códigos HTTP, formato de error, rol y dueño. Descuento de stock probado a nivel de servicio con un Prisma simulado que verifica orden de operaciones y rollback.
- **Integración real con PostgreSQL** (concurrencia de stock, secuencia diaria, CHECK): solo si se define `DATABASE_URL_TEST` apuntando a un esquema o base distinta de los datos de trabajo; si no está definida, se omiten con `describe.skipIf(!process.env.DATABASE_URL_TEST)` y se reporta como omitida.

## Alternativas

- **Usar la misma base `pizzeria` con limpieza tras cada prueba:** riesgo de borrar datos reales.
- **Testcontainers:** requiere Docker (no instalado).
- **SQLite en memoria:** distinto motor, sin `FOR UPDATE` ni `CHECK` equivalentes; prohibido por "PostgreSQL en todos los entornos".

## Consecuencias

- (+) `npm test` pasa en cualquier equipo sin tocar datos.
- (−) La concurrencia real solo se verifica si el usuario habilita una BD/esquema de pruebas (PA-01).

# ADR-001: Monolito con backend en capas (routes → controllers → services → Prisma)

- **Estado:** Aceptado · **Fecha:** 2026-11-06

## Contexto

Restricción fija: un solo repositorio con `backend/` (Node.js/Express) y `frontend/` (Flutter Windows). Un único local, pocos usuarios concurrentes, sin DevOps (S-11). El prompt exige la arquitectura de las skills: Express, Prisma, Zod, JWT, bcrypt, helmet, cors, rate limit.

## Decisión

Backend monolítico con capas estrictas: `routes/` (enrutado + middlewares), `controllers/` (HTTP in/out), `services/` (casos de uso, transacciones, autorización por dueño), `services/pricing-engine/` (motor puro) y `lib/prisma.js` (acceso a datos). `app.js` construye la app sin escuchar (para Supertest) y `server.js` arranca. ES Modules, `async/await`, errores con `AppError` y un `errorHandler` final.

## Alternativas

- **Arquitectura hexagonal con repositorios propios sobre Prisma:** más aislamiento, pero duplica la capa de Prisma sin beneficio real en este tamaño.
- **Controladores con lógica y Prisma directo:** más rápido de escribir, pero impide probar reglas sin HTTP/BD y mezcla responsabilidades.
- **Microservicios (catálogo/pedidos):** descartado por la restricción de monolito y por la necesidad de transacciones entre stock y pedido.

## Consecuencias

- (+) Reglas de negocio probables de forma unitaria; controladores triviales.
- (+) Transacciones locales entre stock, numeración y pedido.
- (−) Disciplina necesaria para no saltarse capas (la revisión de QA lo verifica).

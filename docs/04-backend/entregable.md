# Entregable — Fase 4: Backend

- **Proyecto:** Good Pizza (monolito Node.js + Flutter Windows)
- **Fecha:** 2026-11-06
- **Agente responsable:** backend-dev
- **Versión:** 1.0

## 1. Objetivo de la fase

Implementar en `backend/` la API REST `/api/v1` definida en `docs/02-architecture/api-contract.md` (25 endpoints), el modelo de datos con migraciones Prisma, el motor de cálculo único, el seed de datos de ejemplo y las pruebas automatizadas.

## 2. Resumen ejecutivo

1. API Express en capas `routes -> controllers -> services -> Prisma`, middleware central de errores con el formato `{error:{code,message,details}}` y los 24 códigos del contrato, validación Zod estricta, JWT access 15 min + refresh rotativo con hash en BD, helmet, cors con lista blanca, rate limit global y de autenticación, pino con redacción de secretos.
2. Motor puro `services/pricing-engine/`: precio, calorías, IVA 15 %/0 % sobre los subtotales con half-up, reglas de armado (mínimo 3 distintos solo en personalizadas, máximo 3 porciones receta + extras, masa y salsa), stock agregado y disponibilidad de predefinidas. Lo usan `/orders/quote`, `/orders` y `/preset-pizzas`.
3. Confirmación de pedido en una transacción: `SELECT … FOR UPDATE` ordenado por id, motor, `UPDATE … WHERE stock >= n`, número `GP-AAAAMMDD-NNNN` con contador diario, snapshots e historial; `expectedTotal` opcional (409 `PRICE_CHANGED`).
4. Base `pizzeria` (esquema `public`) migrada con Prisma: 15 tablas y 9 CHECK (incluido `stock >= 0`). No se borró ni recreó nada.
5. Seed idempotente con datos de ejemplo (20 ingredientes, 5 predefinidas, 1 admin, 1 cliente); contraseñas desde `SEED_*_PASSWORD` o generadas e impresas una sola vez. **El seed NO se ejecutó sobre `public`** (para no mostrar contraseñas generadas en una consola que no es la tuya): ejecútalo tú con `npm run db:seed`.
6. 190 pruebas (Vitest + Supertest): 168 pasan sin BD; 22 de integración usan solo el esquema `test` y pasaron (190/190) cuando se habilitaron; `npm test` actual las omite con aviso porque `DATABASE_URL_TEST` no está en `.env.local`. `npm run lint`: 0 errores, 0 advertencias. [Cifra de la fase 4. Actualización de QA (fase 6): `npm test` da 267 pasan y 22 omitidas (289 en total); `npm run lint` limpio.]
7. Arranque real verificado: `npm start` levantó la API y `GET /api/v1/health` respondió 200 con `database: ok` contra `pizzeria`.

## 3. Artefactos producidos

| Artefacto               | Ruta                                                                           | Descripción                                                                                                              |
| ----------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| Código de la API        | `backend/src/`                                                                 | `app.js`, `server.js`, `config/`, `lib/`, `middlewares/`, `routes/`, `controllers/`, `schemas/`, `services/`, `utils/`   |
| Motor de cálculo        | `backend/src/services/pricing-engine/`                                         | `buildPizza`, `validatePizza`, `calculatePizza`, `calculateOrder`, `stockRequirements`, `recipe`, `index` (`quoteOrder`) |
| Esquema y migraciones   | `backend/prisma/schema.prisma`, `backend/prisma/migrations/`                   | Modelo según `data-model.md`; 3 migraciones                                                                              |
| Seed                    | `backend/prisma/seed.js`, `seed-lib.js`                                        | Datos de ejemplo idempotentes                                                                                            |
| Script de pruebas de BD | `backend/scripts/db-test-migrate.js`                                           | Migra solo el esquema `test` (`npm run db:test:migrate`)                                                                 |
| Variables               | `backend/env.template`                                                         | Todas las variables, sin valores reales                                                                                  |
| Pruebas                 | `backend/tests/`                                                               | unit, api, integration, helpers                                                                                          |
| Config                  | `backend/vitest.config.js`, `backend/eslint.config.js`, `backend/package.json` | Scripts `dev`, `start`, `test`, `lint`, `db:*`                                                                           |
| Documentación           | `docs/04-backend/`                                                             | README (cómo correr y endpoints) + 6 entregables                                                                         |

## 4. Decisiones y supuestos

- Decisiones del usuario (fases 1-2) aplicadas: mínimo 3 distintos solo en CUSTOM; precio de predefinidas por fórmula; IVA por subtotal con half-up; cliente no cancela; contraseña >= 8; comprobante solo en pantalla; ingredientes y predefinidas solo se desactivan; zona horaria del servidor; predefinida con ingrediente inactivo o sin stock = no disponible; máximo 20 pizzas por línea, 50 líneas por pedido y 30 extras por pizza; solo CLIENT confirma pedidos; el catálogo del cliente incluye `stock`; PA-01 opción A (esquema `test`).
- Las pruebas con BD real tocan únicamente el esquema `test` (barreras: URL con `?schema=test`, `current_schema() = 'test'`, `DATABASE_URL` forzada en el setup).
- Los CHECK están en una segunda migración porque la migración inicial se aplicó antes de añadirlos (ver README); no se editó ninguna migración aplicada ni se reinició la base.
- Un ingrediente se cuenta en el mínimo de 3 distintos si existe y es de categoría topping (activo o no); si está inactivo se informa además `INGREDIENT_INACTIVE`.
- Aplicación del tope técnico de stock 1 000 000 por ingrediente (para no desbordar INT4) en `SET`/`ADD` y en la creación.
- JSON mal formado o cuerpo > 100 KB responden `400 VALIDATION_ERROR` (el contrato no define 413).
- Bucket de IVA: tarifa 0 % -> `subtotalVat0`; cualquier otra -> `subtotalVat15` (el sistema solo maneja 15 % y 0 %).

## 5. Riesgos y pendientes

| ID   | Riesgo / pendiente                                                                              | Mitigación                                                                                                     |
| ---- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| R-01 | `npm test` omite las 22 pruebas de BD mientras `DATABASE_URL_TEST` no esté en `.env.local`.     | Agregar la variable (ver README) y `npm run db:test:migrate`.                                                  |
| R-02 | La cobertura porcentual no se midió.                                                            | Instalar `@vitest/coverage-v8` en QA (fase 6).                                                                 |
| R-03 | Seed no ejecutado sobre `pizzeria`.                                                             | `npm run db:seed` (el usuario).                                                                                |
| R-04 | Rendimiento de `/orders/quote` (RNF-01 < 200 ms) no medido bajo carga.                          | Fase 6 (QA).                                                                                                   |
| R-05 | Quedó en el esquema `test` de `pizzeria` data de pruebas (se trunca al inicio de cada corrida). | Es el esquema dedicado a pruebas; puede borrarse con `DROP SCHEMA test CASCADE` cuando se decida (no se hizo). |

### Preguntas abiertas

| ID    | Pregunta / inconsistencia detectada                                                                                                                                                                              | Comportamiento aplicado                                                                                                                                                                                                                 |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PA-B1 | `GET /ingredients` y `GET /preset-pizzas`: la matriz de permisos dice que el ADMIN ve "todos", pero el texto define `includeInactive` (solo ADMIN). ¿El valor por defecto del ADMIN es ver todos o solo activos? | Por defecto solo activos para todos; el ADMIN agrega `includeInactive=true` para ver inactivos.                                                                                                                                         |
| PA-B2 | `OrderDetail.pizzas[].presetPizza` pide `{id, code, name}` pero el modelo solo guarda `preset_name_snapshot` (no el código ni el id como snapshot).                                                              | `name` sale del snapshot; `id` y `code` salen de la relación viva (`SetNull`: serían `null` si la predefinida desapareciera; hoy no se borran). Si se quiere snapshot completo, hay que añadir una columna de código (nueva migración). |
| PA-B3 | `quote.stock[]` no incluye `code` aunque `INSUFFICIENT_STOCK.details` sí.                                                                                                                                        | Se respeta el contrato literal (`ingredientId, name, required, available`).                                                                                                                                                             |
| PA-B4 | `GET /orders?search=` es "solo ADMIN": para CLIENT no hay error definido.                                                                                                                                        | Se ignora en silencio para CLIENT.                                                                                                                                                                                                      |
| PA-B5 | Orden de las respuestas 422/409 cuando coinciden varias causas.                                                                                                                                                  | Reglas de armado (422) -> stock (409) -> `expectedTotal` (409).                                                                                                                                                                         |

## 6. Criterios de aceptación de la fase

- [x] Flujo documentado (`flujo.md`)
- [x] Diagrama entidad-relación actualizado (ER físico = `schema.prisma`)
- [x] Pruebas unitarias ejecutadas (resultados reales adjuntos en `pruebas-unitarias.md`)
- [x] Manual de usuario actualizado
- [x] Documentación técnica actualizada
- [x] Migraciones aplicadas a `pizzeria` (3 de 3) y CHECK verificados
- [x] 25 endpoints implementados con el formato de error uniforme
- [ ] Seed ejecutado sobre `pizzeria` (pendiente del usuario: `npm run db:seed`)
- [ ] Pruebas de integración habilitadas por defecto (requiere `DATABASE_URL_TEST` en `.env.local`)

## 7. Aprobación

| Rol                            | Nombre      | Fecha      |
| ------------------------------ | ----------- | ---------- |
| Desarrollador backend (agente) | backend-dev | 2026-11-06 |
| Product owner                  | (pendiente) |            |

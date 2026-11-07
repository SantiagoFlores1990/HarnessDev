# Pruebas unitarias — Fase 4 (Backend)

## Alcance

Vitest 2.1.9 + Supertest sobre `backend/`. Cuatro capas, sin tocar nunca el esquema `public` de `pizzeria`:

| Capa                       | Archivos                                                                                             | Qué prueba                                                                                                                                                                                      | BD                                                                   |
| -------------------------- | ---------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| Motor puro                 | `tests/unit/pricingEngine.test.js` (45)                                                              | Precio, calorías, IVA 15 %/0 % con half-up, mínimo 3 distintos solo en CUSTOM, máximo 3 porciones (receta + extras), masa/salsa, stock agregado, predefinidas, receta del admin, disponibilidad | No                                                                   |
| Utilidades y config        | `tests/unit/utils.test.js` (12)                                                                      | `money` (half-up), número de orden (9999 -> 10000), fechas, validación de variables de entorno                                                                                                  | No                                                                   |
| Servicios con dobles       | `tests/unit/order.service.test.js` (21), `auth.service.test.js` (12), `catalogServices.test.js` (13) | Confirmación transaccional (orden de operaciones, rollback, snapshots, numeración, PRICE_CHANGED), estados, dueño del pedido, auth con rotación de refresh, stock y recetas                     | Doble en memoria (Prisma simulado)                                   |
| API (Supertest)            | `tests/api/endpoints.test.js` (60), `security.test.js` (5)                                           | Los 25 endpoints: éxito, validación 400, 401, 403, 404, errores de negocio, formato de error, rate limit, CORS, helmet                                                                          | No (servicios simulados)                                             |
| Integración con PostgreSQL | `tests/integration/db.test.js` (22)                                                                  | Flujo completo (criterios 1-3 del prompt), concurrencia de stock (IT-B03), secuencia diaria, atomicidad, CHECK, seed idempotente, autenticación real                                            | **Solo esquema `test`** (`DATABASE_URL_TEST`); se omite si no existe |

Total en la fase 4: 190 pruebas (168 sin BD + 22 de integración). Ejecución de QA en la fase 6: 289 (267 pasan + 22 omitidas sin DATABASE_URL_TEST).

## Casos de prueba

Los IDs UT-B/IT-B son los especificados por la fase 2 (`docs/02-architecture/pruebas-unitarias.md`).

| ID      | Historia/RF             | Descripción                                                                   | Entrada                                         | Resultado esperado                                                                                                 | Resultado real                                    | Estado            |
| ------- | ----------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------- | ----------------- |
| UT-B01  | US-07, RF-15            | Precio y calorías CUSTOM                                                      | MEDIUM, masa 2.00, salsa 1.00, queso 1.50 x3    | 7.50; calorías 690                                                                                                 | 7.50 / 690                                        | OK                |
| UT-B01b | Contrato §4             | Ejemplo de referencia (cantidad 2)                                            | masa, salsa, queso x3, jamón, piña              | 9.50; 820 kcal; sub15 15.40; sub0 3.60; IVA 2.31; total 21.31; 1640 kcal                                           | Coincide                                          | OK                |
| UT-B02  | US-10, RF-16            | IVA mixto y half-up                                                           | 0.35; 0.30; 10.00+2.00; 6.50                    | IVA 0.05; 0.05; 1.50 (total 13.50); 0.98                                                                           | Coincide; IVA una vez por pedido (0.09 y no 0.10) | OK                |
| UT-B03  | RF-11, S-17             | < 3 distintos en CUSTOM                                                       | queso x3 + jamón                                | `MIN_TOPPINGS_NOT_MET` (min 3, current 2)                                                                          | Coincide                                          | OK                |
| UT-B04  | S-17                    | Predefinida con 1 topping y sin extras                                        | Margarita                                       | Válida                                                                                                             | Válida; precio por fórmula 6.00                   | OK                |
| UT-B05  | RF-10, RF-14            | Receta 2 + extra 2                                                            | Margarita + queso x2                            | `MAX_PORTIONS_EXCEEDED` (max 3, requested 4)                                                                       | Coincide                                          | OK                |
| UT-B06  | RF-09                   | Sin masa/salsa; masa como topping                                             | doughId ausente, salsa null, masa en toppings   | `DOUGH_REQUIRED`, `SAUCE_REQUIRED`, `INGREDIENT_CATEGORY_NOT_ALLOWED`                                              | Coincide                                          | OK                |
| UT-B07  | RF-12, RF-18            | Stock agregado entre líneas                                                   | masa compartida x6 vs stock 5                   | `INSUFFICIENT_STOCK` solicitado 6, disponible 5                                                                    | Coincide                                          | OK                |
| UT-B08  | RF-18                   | Rollback ante fallo parcial                                                   | falla el descuento de un ingrediente tras otros | Ningún stock cambia, sin pedido                                                                                    | Stock intacto, `rollback` registrado              | OK                |
| UT-B09  | RF-20                   | Formato del número de orden                                                   | día 2026-11-06, 1 / 9999 / 10000                | `GP-20261106-0001` / `-9999` / `-10000`                                                                            | Coincide                                          | OK                |
| IT-B01  | RF-03, US-13            | 401 sin token; 403 cliente en admin; 404 pedido ajeno                         | Supertest                                       | Códigos y formato de error                                                                                         | Coincide (API + integración)                      | OK                |
| IT-B02  | RF-21                   | DELIVERED -> PENDING                                                          | PATCH status                                    | 422 `INVALID_STATUS_TRANSITION`                                                                                    | Coincide                                          | OK                |
| IT-B03  | RF-18, US-11            | 5 confirmaciones simultáneas, stock para 2 pizzas                             | PostgreSQL real (esquema test)                  | 2 x 201 y 3 x 409; stock 1; sin sobreventa                                                                         | 2 / 3 / stock 1                                   | OK (esquema test) |
| IT-B04  | RF-20, ADR-004          | 6 confirmaciones simultáneas                                                  | PostgreSQL real                                 | Correlativo sin huecos ni duplicados                                                                               | `last_value` = nº de pedidos                      | OK (esquema test) |
| IT-B05  | RF-18, ADR-005          | Un ingrediente sin stock en un pedido de varios                               | PostgreSQL real                                 | 409, ningún descuento, número no consumido                                                                         | Coincide                                          | OK (esquema test) |
| IT-B06  | Prompt, criterio 1      | Registro, login, personalizar triple queso, orden con IVA                     | PostgreSQL real                                 | Total 10.07 (sub15 7.10, sub0 1.90, IVA 1.07), 720 kcal, `GP-AAAAMMDD-0001`                                        | Coincide                                          | OK (esquema test) |
| IT-B07  | Prompt, criterios 2 y 3 | Admin cambia precio y stock; pedido antiguo no cambia; avanza hasta Entregado | PostgreSQL real                                 | Pedido antiguo 10.07 con precio 1.20; nuevo 12.83; `PRICE_CHANGED`; estados PENDING -> IN_PREPARATION -> DELIVERED | Coincide                                          | OK (esquema test) |
| IT-B08  | RNF-02                  | CHECK `stock >= 0`                                                            | `UPDATE ... SET stock = -1`                     | PostgreSQL rechaza                                                                                                 | Rechazado; 9 CHECK presentes                      | OK (esquema test) |
| IT-B09  | ADR-006                 | Rotación y reutilización de refresh                                           | login, refresh x2                               | 2.º uso del token viejo 401 y revoca todos                                                                         | Coincide                                          | OK (esquema test) |
| AP-xx   | Matriz de permisos      | Cada endpoint: 401 / 403 / 400 / 404 / éxito                                  | Supertest con servicios simulados               | Contrato §2-§3                                                                                                     | 65 pruebas OK                                     | OK                |

## Ubicación del código de pruebas

- Backend: `backend/tests/unit/`, `backend/tests/api/`, `backend/tests/integration/`, `backend/tests/helpers/` (fábricas de catálogo, doble de BD, tokens, setup que fuerza el esquema de pruebas).
- Flutter: `frontend/test/…` (fase 5).

## Ejecución

```
cd backend
npm test                  # todo; la integración se omite si no hay DATABASE_URL_TEST
npm run lint
npm run db:test:migrate   # prepara el esquema `test` (requiere DATABASE_URL_TEST en .env.local)
```

## Resultados (salida real)

Ejecución 1 — `npm test` tal como lo corre el proyecto (en el `.env.local` actual **no existe** `DATABASE_URL_TEST`, por eso la integración se omite con aviso):

```
> app-backend@0.1.0 test
> dotenv -e .env.local -- vitest run --passWithNoTests

 RUN  v2.1.9 D:/SANTIAGO/CLAUDE-IA/HarnessDev/backend

 ✓ tests/api/endpoints.test.js (60 tests) 997ms
 ↓ tests/integration/db.test.js (22 tests | 22 skipped)
stderr | tests/integration/db.test.js
[AVISO] DATABASE_URL_TEST no está definida: se OMITEN las pruebas de integración con BD real (stock concurrente, secuencia diaria, CHECK, flujo completo). Define DATABASE_URL_TEST en backend/.env.local (misma conexión con ?schema=test) y ejecuta npm run db:test:migrate.
 ✓ tests/unit/pricingEngine.test.js (45 tests) 26ms
 ✓ tests/unit/order.service.test.js (21 tests) 32ms
 ✓ tests/unit/catalogServices.test.js (13 tests) 12ms
 ✓ tests/unit/auth.service.test.js (12 tests) 53ms
 ✓ tests/unit/utils.test.js (12 tests) 11ms
 ✓ tests/api/security.test.js (5 tests) 150ms

 Test Files  7 passed | 1 skipped (8)
      Tests  168 passed | 22 skipped (190)
   Start at  14:11:00
   Duration  4.96s
```

Ejecución 2 — suite completa con la integración habilitada. Para poder verificarla, se ejecutó vitest con `DATABASE_URL_TEST` derivada en memoria de la misma conexión con `?schema=test` (y `DATABASE_URL` forzada a esa misma URL, de modo que nada pudiera tocar `public`); el esquema `test` se creó con `scripts/db-test-migrate.js` (migraciones aplicadas: las 3):

```
 RUN  v2.1.9 D:/SANTIAGO/CLAUDE-IA/HarnessDev/backend

 ✓ tests/api/endpoints.test.js (60 tests) 916ms
 ✓ tests/integration/db.test.js (22 tests) 2293ms
 ✓ tests/unit/pricingEngine.test.js (45 tests) 26ms
 ✓ tests/unit/order.service.test.js (21 tests) 32ms
 ✓ tests/unit/catalogServices.test.js (13 tests) 16ms
 ✓ tests/unit/auth.service.test.js (12 tests) 50ms
 ✓ tests/unit/utils.test.js (12 tests) 11ms
 ✓ tests/api/security.test.js (5 tests) 176ms

 Test Files  8 passed (8)
      Tests  190 passed (190)
   Start at  14:11:08
   Duration  7.02s
```

Lint (`npm run lint`): sin errores ni advertencias.

```
> app-backend@0.1.0 lint
> eslint src tests prisma scripts --no-error-on-unmatched-pattern
```

Comprobación posterior en el esquema `public` (solo lectura): 9 CHECK presentes, 16 tablas (15 del modelo + `_prisma_migrations`), 0 usuarios y 0 pedidos: las pruebas no escribieron en `public`.

## Cobertura

La cobertura porcentual no se midió (no está instalado `@vitest/coverage-v8`). Cobertura funcional: los 25 endpoints, los 24 códigos de error del contrato, las reglas de violación del motor y los casos UT-B01..B09 / IT-B01..B03 de la fase 2 tienen al menos una prueba.

| Módulo                                      | Pruebas |
| ------------------------------------------- | ------- |
| pricing-engine                              | 45      |
| utils/config                                | 12      |
| servicios (order, auth, ingredient, preset) | 46      |
| endpoints y seguridad                       | 65      |
| integración PostgreSQL (esquema test)       | 22      |

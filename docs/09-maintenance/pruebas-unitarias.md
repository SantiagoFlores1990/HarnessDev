# Pruebas unitarias y resultados consolidados — Good Pizza (fase 9)

- **Fecha de redacción:** 2026-11-06 · **Rama:** `testHarness` · **Entorno de referencia:** Windows 11, Node 24.13.1, Flutter 3.47.9 / Dart 3.13.7, Vitest 2.1.9
- **Regla de este documento:** solo se reportan resultados que constan en los entregables e informes de cada fase, con la fecha de su ejecución. **La fase 9 no ha vuelto a ejecutar pruebas** (el orquestador comunicó los estados verificados de esta sesión, indicados como tales). No se inventan cifras.
- **Recuento estático:** una búsqueda `Grep` de `it(`/`test(` en `backend/tests` da 255 coincidencias y en `frontend/test` 181. No coinciden con la ejecución porque hay pruebas generadas por bucles o `it.each`. Las cifras válidas son las de ejecución.

## 1. Resumen por fase

| Fase            | Qué se probó                                                           | Resultado real registrado                                                                                                          | Fuente                                                        |
| --------------- | ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| 1 Requisitos    | Casos de aceptación Given/When/Then (US-01..US-23)                     | Definidos; sin ejecución (no hay código)                                                                                           | `docs/01-requirements/pruebas-unitarias.md`                   |
| 2 Arquitectura  | Consistencia del contrato y del diseño                                 | Revisión manual; sin ejecución                                                                                                     | `docs/02-architecture/pruebas-unitarias.md`                   |
| 3 Diseño        | Consistencia de la especificación y casos de widget previstos          | 38 verificaciones de consistencia y 30 casos de widget (WT-01..WT-30) previstos; sin ejecución en la fase                          | `docs/03-design/pruebas-unitarias.md`                         |
| 4 Backend       | Motor, servicios, API y pruebas de integración                         | 190 (168 sin BD + 22 de integración); lint sin errores. Cifra de la fecha de la fase                                               | `docs/04-backend/pruebas-unitarias.md`                        |
| 5 Frontend      | Widget, unitarias y de flujo (WT-01..WT-30)                            | 221 pruebas OK, `flutter analyze` sin incidencias, cobertura de líneas 93,2 %. Cifra de la fecha de la fase                        | `docs/05-frontend/pruebas-unitarias.md`                       |
| 6 QA            | Ejecución completa con pruebas añadidas                                | Backend 267 pasan, 22 omitidas, 0 fallos. Frontend 225 pasan. `integration_test` en Windows 1 pasa. Cobertura de servicios 97,11 % | `docs/06-qa/test-report.md`                                   |
| 7 Seguridad     | Revisión de seguridad; re-ejecución de pruebas de seguridad existentes | Backend 134 pasan (5 archivos). Flutter 19 pasan (2 archivos). `npm audit` y `flutter pub outdated` ejecutados                     | `docs/07-security/pruebas-unitarias.md`, `security-report.md` |
| 8 DevOps        | —                                                                      | **Omitida** (Docker no instalado)                                                                                                  | `docs/prompt-proyecto.md`                                     |
| 9 Mantenimiento | Verificación documental (conteos, enlaces, coherencia)                 | Sin pruebas de código nuevas                                                                                                       | Este documento                                                |

## 2. Ejecución final (fase 6, la más reciente)

### 2.1 Backend (`backend/`)

Comando: `cd backend && npm test` (con `-- --coverage` para la cobertura).

```
> app-backend@0.1.0 test
> dotenv -e .env.local -- vitest run --passWithNoTests --coverage
 ✓ tests/api/endpoints.test.js (60 tests)
 ↓ tests/integration/db.test.js (22 tests | 22 skipped)
 [AVISO] DATABASE_URL_TEST no está definida: se OMITEN las pruebas de integración con BD real ...
 ✓ tests/unit/services.qa.test.js (22 tests)
 ✓ tests/unit/pricingEngine.test.js (45 tests)
 ✓ tests/unit/seed.qa.test.js (8 tests)
 ✓ tests/api/flows.inprocess.test.js (45 tests)
 ✓ tests/unit/order.service.test.js (21 tests)
 ✓ tests/unit/catalogServices.test.js (13 tests)
 ✓ tests/unit/pricingEngine.edge.test.js (24 tests)
 ✓ tests/unit/auth.service.test.js (12 tests)
 ✓ tests/unit/utils.test.js (12 tests)
 ✓ tests/api/security.test.js (5 tests)
 Test Files  11 passed | 1 skipped (12)
      Tests  267 passed | 22 skipped (289)
```

Cobertura (`@vitest/coverage-v8`, sin contar las pruebas omitidas):

| Módulo                           | % sentencias | % ramas | % funciones |
| -------------------------------- | ------------ | ------- | ----------- |
| Todo `src/`                      | 96,13        | 89,96   | 99,32       |
| `src/services` (criterio ≥ 70 %) | **97,11**    | 88,15   | 100         |
| `src/services/pricing-engine`    | 95,47        | 91,47   | 100         |
| `src/controllers`                | 100          | 100     | 100         |
| `src/routes`                     | 100          | 100     | 100         |
| `src/middlewares`                | 98,26        | 94,11   | 100         |
| `src/schemas`                    | 99,49        | 94,44   | 100         |
| `src/config`                     | 97,74        | 84,61   | 100         |
| `src/utils`                      | 100          | 89,47   | 100         |
| `src/server.js`                  | 0            | 0       | 0           |

Lint: `cd backend && npm run lint` → salida vacía, código de salida 0 (fase 6).

### 2.2 Frontend (`frontend/`)

```
$ flutter analyze
No issues found! (ran in 12.1s)
$ flutter test --coverage
00:49 +225: All tests passed!
$ flutter test integration_test/app_flow_test.dart -d windows
Building Windows application...        31,5s
√ Built build\windows\x64\runner\Debug\good_pizza.exe
00:00 +0: IT-F01 app Windows: registro, triple queso, confirmar y comprobante con IVA
00:06 +1: All tests passed!
```

Cobertura de líneas (`flutter test --coverage`): 3 366 de 3 606 líneas, **93,3 %**. Archivos bajo el 70 %: `core/api/dio_provider.dart` (0 %), `core/theme/app_colors.dart` (55 %), `core/storage/token_storage.dart` (60 %), `features/admin/presentation/admin_orders_page.dart` (67 %). No hay umbral definido para Flutter.

### 2.3 Verificación de esta sesión (fase 9)

El orquestador informa de estos estados verificados en esta sesión: `npm test` = 267 pasan y 22 omitidas; lint limpio; cobertura de `src/services` 97,11 %; `flutter analyze` limpio; `flutter test` = 225 pasan; cobertura 93,3 %; `flutter build windows --debug` compila (`good_pizza.exe`) tras instalar el componente ATL; `integration_test` en Windows pasa con repositorios falsos. **No se han pegado aquí salidas nuevas** porque la fase 9 no las ha generado. Si se requiere salida fresca, ejecutar los comandos de la sección 4.

## 3. Archivos de prueba y su alcance (fase 6)

| Archivo                                                 | Pruebas                                                                      | Qué cubre                                                                                                                                                 |
| ------------------------------------------------------- | ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `backend/tests/unit/pricingEngine.test.js`              | 45                                                                           | Precio, calorías, IVA 15 %/0 % y reglas de armado                                                                                                         |
| `backend/tests/unit/pricingEngine.edge.test.js`         | 24                                                                           | Half-up exhaustivo (20 001 subtotales frente a aritmética entera), límites de porciones, stock exacto, tarifas y datos no confiables (QA-01..QA-04)       |
| `backend/tests/unit/services.qa.test.js`                | 22                                                                           | Servicios `catalog`, `health`, `quote`, `ingredient` y `presetPizza` (QA-20..QA-23)                                                                       |
| `backend/tests/unit/order.service.test.js`              | 21                                                                           | Confirmación, snapshots, dueño y estados                                                                                                                  |
| `backend/tests/unit/catalogServices.test.js`            | 13                                                                           | Catálogos                                                                                                                                                 |
| `backend/tests/unit/auth.service.test.js`               | 12                                                                           | Registro, login, refresh con rotación y reutilización, logout                                                                                             |
| `backend/tests/unit/utils.test.js`                      | 12                                                                           | Utilidades (dinero, fechas, número de orden)                                                                                                              |
| `backend/tests/unit/seed.qa.test.js`                    | 8                                                                            | Datos del seed y contraseñas generadas (QA-30/31)                                                                                                         |
| `backend/tests/api/endpoints.test.js`                   | 60                                                                           | Endpoints y formato de error                                                                                                                              |
| `backend/tests/api/flows.inprocess.test.js`             | 45                                                                           | Flujos HTTP completos en proceso, matriz de permisos 401/403 y rendimiento de la cotización (QA-10..QA-16)                                                |
| `backend/tests/api/security.test.js`                    | 5                                                                            | Casos de abuso y seguridad                                                                                                                                |
| `backend/tests/integration/db.test.js`                  | 22 (**omitidas**)                                                            | Flujo completo contra PostgreSQL, concurrencia de stock (IT-B03/B04), secuencia diaria, CHECK, seed idempotente y autenticación real. Solo esquema `test` |
| `frontend/test/core/*`                                  | varios                                                                       | Formato de dinero, interceptor, router, excepciones de API, repositorios dio, contraste (WT-01)                                                           |
| `frontend/test/features/*`                              | varios                                                                       | Pantallas de auth, presets, armado, carrito, pedidos, administración, navegación y accesibilidad                                                          |
| `frontend/test/flows/customize_to_order_flow_test.dart` | varias (recuento estático: 2 `test(`; no verificado en ejecución individual) | Flujo "personalizar pizza hasta generar la orden"                                                                                                         |
| `frontend/test/flows/journeys_flow_test.dart`           | 4                                                                            | QA-F01..F04: registro, pedido, Mis pedidos, administración y cambio de estado                                                                             |
| `frontend/integration_test/app_flow_test.dart`          | 1                                                                            | IT-F01: app de Windows (registro, triple queso, confirmar, comprobante con IVA)                                                                           |

## 4. Cómo ejecutar las pruebas

| Objetivo                                 | Comando                                                                      | Requisito                                              |
| ---------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------ |
| Backend, pruebas sin base de datos       | `cd backend && npm test`                                                     | Ninguno                                                |
| Backend, con cobertura                   | `cd backend && npx vitest run --coverage`                                    | Ninguno. Usar `npx vitest` no carga `.env.local`       |
| Backend, lint                            | `cd backend && npm run lint`                                                 | Ninguno                                                |
| Backend, integración con PostgreSQL (22) | `npm run db:test:migrate` y después `npm test`                               | `DATABASE_URL_TEST` con `?schema=test` en `.env.local` |
| Frontend, análisis estático              | `cd frontend && flutter analyze`                                             | Flutter instalado                                      |
| Frontend, pruebas                        | `cd frontend && flutter test`                                                | Ninguno                                                |
| Frontend, cobertura                      | `cd frontend && flutter test --coverage`                                     | Ninguno                                                |
| Frontend, escritorio                     | `cd frontend && flutter test integration_test/app_flow_test.dart -d windows` | Windows con ATL instalado                              |

## 5. Pruebas de seguridad (fase 7)

Re-ejecución de las pruebas existentes (sin cargar `.env.local`):

```
$ cd backend && npx vitest run tests/api/security.test.js tests/api/endpoints.test.js tests/api/flows.inprocess.test.js tests/unit/auth.service.test.js tests/unit/utils.test.js
 ✓ tests/api/endpoints.test.js (60 tests)
 ✓ tests/api/flows.inprocess.test.js (45 tests)
 ✓ tests/unit/auth.service.test.js (12 tests)
 ✓ tests/unit/utils.test.js (12 tests)
 ✓ tests/api/security.test.js (5 tests)
 Test Files  5 passed (5)
      Tests  134 passed (134)

$ cd frontend && flutter test test/core/auth_interceptor_test.dart test/core/router_test.dart
00:03 +19: All tests passed!
```

Casos de seguridad propuestos y no implementados (ver backlog): SEC-N01 a SEC-N13. Casos clave: `change-me` en `development` debe fallar (N01); `alg: none` y refresh como Bearer dan 401 (N02, N03); usuario desactivado o inexistente en rutas ADMIN (N04); límites por IP (N05); arreglos grandes (N06); tope de pizzas (N07); `page` enorme (N08); logs sin datos sensibles (N09); seed con contraseña corta (N10); cliente no-loopback en `release` (N11); cierre por inactividad (N12); integración con `test` (N13).

## 6. Rendimiento de `POST /orders/quote` (RNF-01 < 200 ms)

Medido en proceso con Supertest, sin base de datos (Prisma sustituido por un doble en memoria). 20 peticiones de calentamiento y 200 medidas por escenario. Resultados de la fase 6:

| Escenario | n   | p50 (ms) | p95 (ms) | p99 (ms) | máx (ms) | media (ms) |
| --------- | --- | -------- | -------- | -------- | -------- | ---------- |
| 1 línea   | 200 | 5,86     | 6,50     | 6,99     | 8,06     | 5,89       |
| 10 líneas | 200 | 7,27     | 9,16     | 10,93    | 13,38    | 7,47       |

No incluye latencia de PostgreSQL. La medición con la base real está en el backlog (DT-07).

## 7. Lo que no está verificado por pruebas automáticas

- Las 22 pruebas de integración con PostgreSQL real (concurrencia, secuencia diaria, CHECK): **omitidas** hasta definir `DATABASE_URL_TEST` (D-05).
- `flutter run -d windows` contra el backend real con datos del seed (G-12).
- `flutter_secure_storage` real y `dio_provider.dart` (G-13).
- Revisión visual a escala de texto de 125-200 % (G-14).
- `server.js` (arranque): sin pruebas (DT-04).

## 8. Resultados históricos

Las salidas de las fases 4 y 5 se conservan en sus carpetas. Sus cifras (190 y 221) son las de su fecha. Las correcciones de conteo están en `docs/09-maintenance/correcciones-pendientes.md`.

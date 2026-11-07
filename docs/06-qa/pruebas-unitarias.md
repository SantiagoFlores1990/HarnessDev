# Pruebas unitarias — Fase 6 (QA)

## Alcance

Consolidación de todas las pruebas del proyecto más las añadidas por QA. Las de las fases 4 y 5 están detalladas en `docs/04-backend/pruebas-unitarias.md` y `docs/05-frontend/pruebas-unitarias.md`; aquí se listan los casos nuevos (IDs `QA-xx`, `QA-Fxx`, `IT-F01`) y los resultados reales de la ejecución completa. Los conteos de esos dos documentos quedaron desactualizados (D-02 en `test-report.md`).

Restricciones respetadas: no se leyó `.env.local`; ninguna prueba escribe en `pizzeria.public`; las pruebas con BD real solo usan el esquema `test` y se omiten porque `DATABASE_URL_TEST` no existe en este entorno.

## Casos de prueba (nuevos de la fase 6)

| ID     | Historia/RF       | Descripción                                                                                       | Entrada                                                  | Resultado esperado                                                                     | Resultado real                      | Estado |
| ------ | ----------------- | ------------------------------------------------------------------------------------------------- | -------------------------------------------------------- | -------------------------------------------------------------------------------------- | ----------------------------------- | ------ |
| QA-01  | US-10, RF-16      | IVA half-up para todos los subtotales de 0.00 a 200.00                                            | 20 001 subtotales; referencia en centavos enteros        | IVA y total idénticos a `floor((c*15+50)/100)`                                         | 0 diferencias                       | OK     |
| QA-01  | US-10             | Bordes: 0.03, 0.04, 0.10, 0.30, 0.70, 1.10, 1.30, 0.01, 0.00                                     | subtotal 15 %                                            | 0.00, 0.01, 0.02, 0.05, 0.11, 0.17, 0.20, 0.00, 0.00                                   | Coincide                            | OK     |
| QA-02  | US-09, S-26       | 20 pizzas en una línea                                                                            | triple queso + jamón + champiñones, cantidad 20          | 209.10 total; 15 900 kcal; stock requerido 20/20/60/20/20                              | Coincide                            | OK     |
| QA-02  | US-06             | Stock exacto vs uno menos                                                                         | queso 60 y 59                                            | válido / `INSUFFICIENT_STOCK` pedido 60 disponible 59                                   | Coincide                            | OK     |
| QA-03  | US-05, US-08      | 3 distintos x 3 porciones; extra sobre receta suma al máximo; extras que no pierden la receta     | CUSTOM y Margarita                                       | válido; `MAX_PORTIONS_EXCEEDED` (4); receta intacta                                    | Coincide                            | OK     |
| QA-04  | US-18, RNF-04     | El motor ignora precios del ítem; 15 % -> 0 % mueve el importe a Subtotal 0 %                    | ítem con `unitPrice` falso; queso con IVA 0              | precio 6.30 del catálogo; Sub0 6.10 y Sub15 3.20                                       | Coincide                            | OK     |
| QA-10  | US-11, US-12, criterio 1 | Confirmar y consultar por HTTP                                                             | POST /orders triple queso                                | 201, `Location`, `GP-AAAAMMDD-0001`, totales 7.70/1.60/1.16/10.46, 795 kcal            | Coincide; GET idéntico              | OK     |
| QA-10  | RNF-04, US-11     | Campos de precio -> 400; `expectedTotal` desfasado -> 409; stock insuficiente sin cambios        | payloads                                                 | 400, 409 `PRICE_CHANGED`, 409 `INSUFFICIENT_STOCK` con ingrediente; stock intacto      | Coincide                            | OK     |
| QA-10  | US-09, US-04, US-08 | 21 pizzas, mínimo de 3 y Margarita                                                            | payloads                                                 | 400; 422 con "Elige al menos 3 ingredientes distintos"; Margarita 201, +2 queso 422    | Coincide                            | OK     |
| QA-11  | US-14, criterio 3 | Cambio de precio, calorías, tarifa y nombre; desactivar y agotar                                 | modificar el catálogo tras confirmar                     | pedido antiguo idéntico; pedido nuevo con 9.99 / 999 kcal / IVA 0                      | Coincide                            | OK     |
| QA-12  | US-13, RF-03      | Dueño y sin cancelación                                                                           | otro cliente; DELETE/PUT/cancel; PATCH como cliente      | 404 por id, lista vacía; 404 `ROUTE_NOT_FOUND`; 403; pedido Pendiente; stock sin devolver | Coincide                         | OK     |
| QA-13  | US-20, criterio 2 | Estados por HTTP                                                                                  | saltos, avance, retrocesos                               | 422 en saltos y retrocesos; el cliente ve el nuevo estado; historial de 3 estados      | Coincide                            | OK     |
| QA-14  | US-22             | Matriz de permisos                                                                                | 9 rutas ADMIN con token de cliente; 20 rutas sin token   | 403 `FORBIDDEN`; 401 `UNAUTHENTICATED`                                                 | 29 casos OK                         | OK     |
| QA-15  | US-23             | Rutas fuera de `/api/v1`                                                                          | GET /health                                              | 404 `ROUTE_NOT_FOUND`                                                                  | Coincide                            | OK     |
| QA-16  | RNF-01            | Rendimiento de `POST /orders/quote` en proceso                                                    | 200 muestras, 1 y 10 líneas                              | p95 < 200 ms                                                                           | p95 6.50 ms y 9.16 ms               | OK     |
| QA-20  | US-16, US-23      | Servicios de catálogo y salud                                                                     | doble de Prisma                                          | formato de tarifa 2 decimales; 503 sin filtrar el error interno                        | Coincide                            | OK     |
| QA-21  | US-07, RF-13      | `quote.service`: 7.50 / 690 kcal; no escribe                                                      | masa 2.00 + salsa 1.00 + queso 1.50 x3                   | precio 7.50, `MIN_TOPPINGS_NOT_MET`; sin escrituras                                    | Coincide                            | OK     |
| QA-22  | US-15..US-17      | Ingredientes: listado y filtros, paginación, edición, categoría bloqueada, P2002, defaults, stock | doble de Prisma                                          | contrato §2.4                                                                          | Coincide (11 casos)                 | OK     |
| QA-23  | US-03, US-19      | Predefinidas: precio por fórmula, no disponible, edición transaccional, 422, P2002, baja lógica   | doble de Prisma                                          | contrato §2.5                                                                          | Coincide (7 casos)                  | OK     |
| QA-30  | US-21, RF-26      | Datos del seed                                                                                    | `SAMPLE_INGREDIENTS`, `SAMPLE_PRESETS`                   | 20 ingredientes, 3 masas, 3 salsas, mezcla 15/0 %, 5 predefinidas válidas y disponibles | Coincide                            | OK     |
| QA-31  | US-21, RNF-03     | Contraseñas del seed                                                                              | `seedUsers` con doble de Prisma                          | aleatorias y distintas, solo hash bcrypt; no genera si hay variable; idempotente       | Coincide                            | OK     |
| QA-F01 | US-01..US-13, criterio 1 | UI: registro -> triple queso -> pedido -> confirmar -> comprobante -> Mis pedidos          | `flutter_test` con repositorios falsos                   | total $ 10.89; 805 kcal; pedido Pendiente en la lista                                  | Coincide                            | OK     |
| QA-F02 | US-17, US-20, criterio 2 | UI: admin edita precio, ajusta stock y avanza a Entregado                                  | `flutter_test`                                           | PUT con 1.75; SET 200; En preparación y Entregado; sin más acciones                     | Coincide                            | OK     |
| QA-F03 | US-02, US-22      | UI: sin sesión se exige iniciar sesión                                                            | /cart y /builder sin sesión                              | pantalla de login; sin llamadas de pedido                                              | Coincide                            | OK     |
| QA-F04 | US-13             | UI: el cliente ve el estado que puso el admin                                                     | "Actualizar"                                             | En preparación                                                                         | Coincide                            | OK     |
| IT-F01 | RNF-07, criterio 4 | App Windows real: login, triple queso, confirmar, comprobante                                    | `integration_test -d windows`                            | total $ 10.89, IVA desglosado                                                          | Coincide                            | OK     |

## Ubicación del código de pruebas

- Backend: `backend/tests/unit/` (`pricingEngine.edge.test.js`, `services.qa.test.js`, `seed.qa.test.js` nuevos), `backend/tests/api/flows.inprocess.test.js` (nuevo), `backend/tests/integration/db.test.js` (BD real, omitido), `backend/tests/helpers/`.
- Flutter: `frontend/test/flows/journeys_flow_test.dart` (nuevo), `frontend/test/features/`, `frontend/test/core/`, `frontend/integration_test/app_flow_test.dart` (nuevo).

## Ejecución

```
cd backend && npm test                      # Vitest + Supertest (la integración se omite sin DATABASE_URL_TEST)
cd backend && npm test -- --coverage        # cobertura con @vitest/coverage-v8
cd backend && npm run lint
cd frontend && flutter analyze
cd frontend && flutter test --coverage
cd frontend && flutter test integration_test/app_flow_test.dart -d windows
```

Si `flutter` no está en el PATH: `C:\src\flutter\bin\flutter.bat`.

## Resultados (salida real)

```
> app-backend@0.1.0 test
> dotenv -e .env.local -- vitest run --passWithNoTests --coverage

 ✓ tests/api/endpoints.test.js (60 tests)
 ↓ tests/integration/db.test.js (22 tests | 22 skipped)
[AVISO] DATABASE_URL_TEST no está definida: se OMITEN las pruebas de integración con BD real ...
 ✓ tests/unit/services.qa.test.js (22 tests)
 ✓ tests/unit/pricingEngine.test.js (45 tests)
 ✓ tests/unit/seed.qa.test.js (8 tests)
[QA-16] quote 1 línea (ms): {"n":200,"p50":5.86,"p95":6.5,"p99":6.99,"max":8.06,"mean":5.89}
[QA-16] quote 10 líneas (ms): {"n":200,"p50":7.27,"p95":9.16,"p99":10.93,"max":13.38,"mean":7.47}
 ✓ tests/api/flows.inprocess.test.js (45 tests)
 ✓ tests/unit/order.service.test.js (21 tests)
 ✓ tests/unit/catalogServices.test.js (13 tests)
 ✓ tests/unit/pricingEngine.edge.test.js (24 tests)
 ✓ tests/unit/auth.service.test.js (12 tests)
 ✓ tests/unit/utils.test.js (12 tests)
 ✓ tests/api/security.test.js (5 tests)

 Test Files  11 passed | 1 skipped (12)
      Tests  267 passed | 22 skipped (289)
   Duration  12.43s
```

```
> app-backend@0.1.0 lint
> eslint src tests prisma scripts --no-error-on-unmatched-pattern
(sin salida; código de salida 0)
```

```
$ flutter analyze
Analyzing frontend...
No issues found! (ran in 12.1s)

$ flutter test --coverage
00:49 +225: All tests passed!

$ flutter test integration_test/app_flow_test.dart -d windows
Building Windows application...        31,5s
√ Built build\windows\x64\runner\Debug\good_pizza.exe
00:00 +0: IT-F01 app Windows: registro, triple queso, confirmar y comprobante con IVA
00:06 +1: All tests passed!
```

## Cobertura

| Módulo                               | % (sentencias en backend, líneas en Flutter) |
| ------------------------------------ | -------------------------------------------- |
| Backend, todo `src/`                 | 96.13                                        |
| Backend, `src/services` (criterio ≥ 70 %) | **97.11**                               |
| Backend, `pricing-engine`            | 95.47                                        |
| Backend, `controllers` / `routes`    | 100 / 100                                    |
| Backend, `middlewares` / `schemas`   | 98.26 / 99.49                                |
| Frontend, total                      | 93.3                                         |
| Frontend, `features/admin`           | 87.3                                         |
| Frontend, `features/pizza_builder`   | 92.6                                         |
| Frontend, `core/storage`             | 60.0                                         |

Detalle y límites de la medición en `test-report.md` §4.

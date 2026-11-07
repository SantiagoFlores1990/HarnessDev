# Documentación técnica — Fase 6 (QA)

## 1. Visión técnica

La infraestructura de pruebas del proyecto: Vitest y Supertest en el backend, `flutter_test` e `integration_test` en el frontend. Se prioriza una pirámide con muchas pruebas rápidas y sin base de datos, y pocas pruebas con PostgreSQL real restringidas al esquema `test`.

## 2. Arquitectura y componentes

| Componente                     | Ruta                                                    | Función                                                                                                          |
| ------------------------------ | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Configuración de Vitest        | `backend/vitest.config.js`                              | Entorno `node`, variables fijas de prueba (no secretos reales), `fileParallelism: false`, proveedor de cobertura `v8` |
| Setup de pruebas               | `backend/tests/helpers/setup.js`                        | Fuerza `DATABASE_URL` a `DATABASE_URL_TEST` o a una URL inválida: nada puede tocar `public`                       |
| Doble de BD en memoria         | `backend/tests/helpers/fakeDb.js`                       | Prisma simulado con `$transaction` con commit/rollback; usado por `order.service` y por los flujos HTTP           |
| Fábricas de catálogo           | `backend/tests/helpers/catalog.js`, `tokens.js`         | Ingredientes, predefinida Margarita, JWT de cliente, otro cliente y administrador                                  |
| Doble de Prisma con `vi.fn()`  | `vi.mock("../../src/lib/prisma.js")` en `catalogServices.test.js` y `services.qa.test.js` | Pruebas de servicios con respuestas controladas                                    |
| Repositorios falsos Flutter    | `frontend/test/helpers/fakes.dart`, `fixtures.dart`, `pump_app.dart`, `finders.dart` | `FakeBackend` con un doble del motor del servidor; `pumpGoodPizza` arranca la app completa                          |
| E2E de escritorio              | `frontend/integration_test/app_flow_test.dart`          | Reutiliza los falsos de `test/helpers`; fija una vista lógica de 1600x1300                                        |

Qué es doble y qué es real en cada capa:

| Prueba                         | Real                                                         | Doble                                |
| ------------------------------ | ------------------------------------------------------------ | ------------------------------------ |
| `pricingEngine*.test.js`       | Motor puro                                                   | —                                    |
| `endpoints.test.js`            | Rutas, Zod, middlewares                                      | Servicios                            |
| `flows.inprocess.test.js`      | Rutas, Zod, JWT, controladores, servicios y motor            | Solo Prisma (`fakeDb`)               |
| `services.qa.test.js`          | Servicios y motor                                            | Prisma con `vi.fn()`                 |
| `db.test.js`                   | Todo, incluido PostgreSQL (esquema `test`)                   | —                                    |
| `journeys_flow_test.dart`      | App completa (router, tema, controladores)                   | Repositorios (sin red)               |
| `app_flow_test.dart`           | App compilada para Windows, ventana y render reales          | Repositorios (sin red)               |

Limitación del doble en memoria: `$transaction` clona el estado al inicio y lo confirma al final, por lo que no modela bloqueos ni concurrencia; por eso no hay pruebas de concurrencia con él (solo las de PostgreSQL real).

## 3. Tecnologías y versiones

| Componente        | Tecnología                       | Versión                          |
| ----------------- | -------------------------------- | -------------------------------- |
| Pruebas backend   | Vitest                           | 2.1.9                            |
| Cobertura backend | `@vitest/coverage-v8` (nuevo)    | 2.1.9                            |
| HTTP en pruebas   | Supertest                        | ^7.0.0                           |
| Lint              | ESLint / Prettier                | ^9.14.0 / ^3.3.3                 |
| Pruebas Flutter   | `flutter_test`, `integration_test` (nuevo, SDK) | Flutter 3.47.9, Dart 3.13.7 |
| Node.js           | Node                             | 24.13.1 (requisito del proyecto >= 20) |

## 4. Estructura de carpetas

```
backend/tests/
  unit/        pricingEngine, pricingEngine.edge (QA), order.service, auth.service, catalogServices,
               services.qa (QA), seed.qa (QA), utils
  api/         endpoints, security, flows.inprocess (QA)
  integration/ db.test.js (PostgreSQL real, esquema test; se omite sin DATABASE_URL_TEST)
  helpers/     setup, fakeDb, catalog, tokens
frontend/test/        core/, features/, flows/ (customize_to_order_flow, journeys_flow (QA)), helpers/
frontend/integration_test/app_flow_test.dart
```

## 5. Configuración y variables de entorno

Solo nombres y propósito; nunca valores.

| Variable                                   | Uso en pruebas                                                                              |
| ------------------------------------------ | ------------------------------------------------------------------------------------------- |
| `DATABASE_URL_TEST`                        | Habilita las pruebas con BD real (esquema `test`). Sin ella se omiten                       |
| `DATABASE_URL`                             | El setup la sustituye por la de prueba o por una inválida                                   |
| `JWT_SECRET`, `JWT_REFRESH_SECRET`, `BCRYPT_COST`, límites de tasa | Fijadas en `vitest.config.js` con valores de prueba (no secretos reales)    |
| `API_URL` (`--dart-define`)                | Dirección del backend en la app; las pruebas la sustituyen por repositorios falsos           |

`backend/.env.local` no se lee ni se modifica; los scripts npm lo cargan con `dotenv-cli`.

## 6. API / Interfaces

Sin cambios en la API (25 endpoints). Las pruebas la ejercen según `docs/02-architecture/api-contract.md`; la matriz de permisos está en `flows.inprocess.test.js` (QA-14).

## 7. Base de datos

Sin cambios. Esquema, migraciones y seed de la fase 4; ER consolidado en `diagrama-er.md`. Las pruebas con BD real usan solo el esquema `test` (barreras: URL con `?schema=test`, `current_schema() = 'test'` y `DATABASE_URL` forzada).

## 8. Instalación y ejecución

```
cd backend && npm install && npm test && npm run lint
cd backend && npm test -- --coverage
cd frontend && flutter pub get && flutter analyze && flutter test --coverage
cd frontend && flutter test integration_test/app_flow_test.dart -d windows
```

Cobertura backend: informe en `backend/coverage/`; frontend: `frontend/coverage/lcov.info`. Ambas carpetas son artefactos generados (`coverage/` está en `.gitignore`).

## 9. Pruebas

Resultados reales, cobertura y rendimiento: `test-report.md` y `pruebas-unitarias.md`. Resumen: backend 267 pasan y 22 omitidas; servicios 97.11 %; Flutter 225 pasan y 1 de integración; `flutter analyze` sin problemas.

Rendimiento de `POST /orders/quote`: prueba QA-16, 200 muestras por escenario con `performance.now()`, en proceso y sin BD (p95 6.50 ms y 9.16 ms). Los umbrales son holgados (p95 < 200 ms) para no producir falsos fallos por ruido del equipo; las cifras reales se imprimen en la salida.

## 10. Seguridad

- Las pruebas no contienen contraseñas reales; los JWT se firman con secretos fijos de prueba definidos en `vitest.config.js`; el seed de prueba usa contraseñas inline solo en dobles (`clave-de-prueba-*`).
- Ninguna prueba escribe en `pizzeria.public`. El comando de integración exige el esquema `test`.
- Observación D-03 (token de un usuario desactivado) pasa a la fase de seguridad.

## 11. Despliegue y operación

No aplica (la fase DevOps se omite por decisión del proyecto). Las pruebas se ejecutan en local; no hay CI.

## 12. Decisiones (ADR) y deuda técnica

- QA-D1: se mide el rendimiento en proceso para no escribir en ninguna BD; queda pendiente medirlo con PostgreSQL real.
- QA-D2: el E2E de escritorio usa repositorios falsos; un E2E contra el backend real requiere una base de pruebas y datos sembrados (pendiente).
- Deuda: 22 pruebas de BD sin ejecutar en esta sesión (D-05); `dio_provider.dart` y `token_storage.dart` con baja cobertura; no se añadió un script `test:coverage` en `package.json` (se usa `npm test -- --coverage`).
- Los conteos de pruebas en `docs/04-backend` y `docs/05-frontend` y el estado de la compilación Windows en `docs/05-frontend` están desactualizados (D-01, D-02).

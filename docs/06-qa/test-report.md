# Informe de pruebas — Good Pizza (Fase 6, QA)

Fecha de ejecución: 2026-11-06 · Rama `testHarness` · Windows 11 · Node 24.13.1 · Flutter 3.47.9 / Dart 3.13.7 · Vitest 2.1.9.
Plan y trazabilidad: `docs/06-qa/test-plan.md`. Todas las cifras de este documento salen de ejecuciones reales de esta sesión.

## 1. Veredicto

**GO CONDICIONADO.** No hay defectos bloqueantes ni funcionales abiertos en lo que se pudo ejecutar. Los criterios de salida medibles se cumplen: 0 fallos, servicios del backend con 97.11 % de cobertura (umbral 70 %), `flutter analyze` sin problemas, lint limpio.

Condiciones (no cumplirlas deja el proyecto sin verificar, no con defectos conocidos):

1. Las **22 pruebas de integración con PostgreSQL real** (concurrencia de stock, secuencia diaria, CHECK, criterios 1-3 contra la BD) **se omitieron** porque `DATABASE_URL_TEST` no existe en el entorno. No se derivó la URL desde `.env.local`. Los criterios 1-3 se verificaron en proceso (servicios reales con un doble de Prisma) y en la UI, pero **no contra la base real**. La concurrencia real no se verificó en esta sesión.
2. No se ejecutó `flutter run -d windows` contra el backend real con datos del seed. El arranque de la app compilada se verificó con `integration_test -d windows` (construye y lanza `good_pizza.exe`), con repositorios falsos.

## 2. Resultados de ejecución

| Comando                                                   | Resultado real                                                                                                   |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `cd backend && npm test` (con `-- --coverage`)            | **11 archivos pasan, 1 omitido; 267 pruebas pasan, 22 omitidas (289); 0 fallos.** Duración 12.43 s                |
| `cd backend && npm run lint`                              | Salida vacía, código de salida 0 (0 errores, 0 advertencias)                                                      |
| `cd frontend && flutter analyze`                          | `No issues found! (ran in 12.1s)`                                                                                 |
| `cd frontend && flutter test --coverage`                  | `+225: All tests passed!` (0 fallos)                                                                              |
| `cd frontend && flutter test integration_test/app_flow_test.dart -d windows` | `Built build\windows\x64\runner\Debug\good_pizza.exe` · `+1: All tests passed!`                  |

Evolución respecto a la línea base de las fases 4 y 5: backend 168 -> 267 pruebas pasando (+99 nuevas; las 22 omitidas son las mismas); frontend 221 -> 225 (+4) más 1 de integración.

### Salida real (resumen)

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

## 3. Pruebas añadidas en esta fase

| Archivo                                          | Pruebas | Cubre                                                                                                                                                       |
| ------------------------------------------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `backend/tests/unit/pricingEngine.edge.test.js`  | 24      | QA-01 half-up exhaustivo (20 001 subtotales vs aritmética entera) y bordes; QA-02 20 pizzas y stock exacto; QA-03 límites de porciones; QA-04 tarifas y datos no confiables |
| `backend/tests/api/flows.inprocess.test.js`      | 45      | QA-10..QA-16: flujos HTTP con servicios reales (confirmar, snapshots, dueño, sin cancelación, estados, matriz de permisos 401/403, rendimiento)               |
| `backend/tests/unit/services.qa.test.js`         | 22      | QA-20..QA-23: servicios `catalog`, `health`, `quote`, `ingredient`, `presetPizza`                                                                           |
| `backend/tests/unit/seed.qa.test.js`             | 8       | QA-30/31: datos del seed y contraseñas generadas                                                                                                            |
| `frontend/test/flows/journeys_flow_test.dart`    | 4       | QA-F01 registro->pedido->Mis pedidos; QA-F02 admin precio->stock->Entregado; QA-F03 guard sin sesión; QA-F04 el cliente ve el nuevo estado                  |
| `frontend/integration_test/app_flow_test.dart`   | 1       | IT-F01 app Windows real (ventana y render reales)                                                                                                           |

Cambios de soporte (no tocan comportamiento): `@vitest/coverage-v8@2.1.9` como devDependency (`backend/package.json` y lockfile), `integration_test` (SDK Flutter) en `dev_dependencies` de `frontend/pubspec.yaml`, `coverage/` agregado a `.gitignore`. No se debilitó ni borró ninguna prueba existente.

## 4. Cobertura

### 4.1 Backend (`@vitest/coverage-v8`, 267 pruebas; las de BD omitidas no suman)

| Módulo                        | % Sentencias | % Ramas | % Funciones |
| ----------------------------- | ------------ | ------- | ----------- |
| **Todos (`src/`)**            | 96.13        | 89.96   | 99.32       |
| **`src/services` (criterio)** | **97.11**    | 88.15   | 100         |
| `src/services/pricing-engine` | 95.47        | 91.47   | 100         |
| `src/controllers`             | 100          | 100     | 100         |
| `src/routes`                  | 100          | 100     | 100         |
| `src/middlewares`             | 98.26        | 94.11   | 100         |
| `src/schemas`                 | 99.49        | 94.44   | 100         |
| `src/config`                  | 97.74        | 84.61   | 100         |
| `src/utils`                   | 100          | 89.47   | 100         |
| `src/server.js`               | 0            | 0       | 0           |

Servicios más bajos: `auth.service.js` 92.5 %, `order.service.js` 91.86 % (ramas de captura de errores y de refresco). Antes de esta fase `src/services` estaba en 73.17 % (`quote` 23 %, `catalog` 13 %, `health` 16 %, `presetPizza` 41 %, `ingredient` 57 %). `server.js` (arranque) no se prueba en pruebas automáticas. Limitación: la cobertura se obtuvo con dobles de Prisma; el SQL real (`FOR UPDATE`, secuencias, CHECK) solo lo ejercen las pruebas (BD) omitidas.

### 4.2 Frontend (`flutter test --coverage`, líneas)

| Módulo                     | Líneas cubiertas / total | %     |
| -------------------------- | ------------------------ | ----- |
| **Total**                  | 3366 / 3606              | 93.3  |
| `core/widgets`             | 416 / 419                | 99.3  |
| `core/router`              | 68 / 68                  | 100.0 |
| `core/api`                 | 80 / 98                  | 81.6  |
| `core/storage`             | 12 / 20                  | 60.0  |
| `core/theme`               | 117 / 131                | 89.3  |
| `features/admin`           | 924 / 1058               | 87.3  |
| `features/auth`            | 257 / 264                | 97.3  |
| `features/cart`            | 237 / 244                | 97.1  |
| `features/catalog`         | 115 / 115                | 100.0 |
| `features/orders`          | 505 / 518                | 97.5  |
| `features/pizza_builder`   | 402 / 434                | 92.6  |
| `features/preset_pizzas`   | 174 / 175                | 99.4  |

Archivos bajo 70 %: `core/api/dio_provider.dart` 0 % (cableado de Dio y `API_URL`), `core/theme/app_colors.dart` 55 %, `core/storage/token_storage.dart` 60 % (implementación real con `flutter_secure_storage`), `features/admin/presentation/admin_orders_page.dart` 67 %. Nota: `flutter test --coverage` solo informa los archivos importados por las pruebas; `main.dart` no figura. No hay umbral de cobertura definido para Flutter.

## 5. Rendimiento de `POST /orders/quote` (RNF-01 < 200 ms)

Metodología (prueba QA-16, `backend/tests/api/flows.inprocess.test.js`):

- Se mide por HTTP en proceso con Supertest sobre `createApp()`: ruta real, validación Zod, `requireAuth` (JWT real), controlador, `quote.service` y motor `quoteOrder`. Prisma se sustituye por el doble en memoria (`fakeDb`): **no hay base de datos ni red**, por tanto **no incluye latencia de PostgreSQL**; no se escribe en `public` ni en ninguna BD.
- 20 peticiones de calentamiento y 200 medidas por escenario; tiempo con `performance.now()` alrededor de cada `await request(...)`.
- Escenarios: 1 línea (triple queso, 5 componentes) y 10 líneas (tamaños y cantidades variadas).

Resultados reales (última ejecución, ms):

| Escenario | n   | p50  | p95  | p99   | máx   | media |
| --------- | --- | ---- | ---- | ----- | ----- | ----- |
| 1 línea   | 200 | 5.86 | 6.50 | 6.99  | 8.06  | 5.89  |
| 10 líneas | 200 | 7.27 | 9.16 | 10.93 | 13.38 | 7.47  |

Conclusión: el servicio y el motor cumplen con amplio margen (p95 < 10 ms frente al límite de 200 ms). La cifra de extremo a extremo con PostgreSQL real no se midió (la cotización hace 3 consultas de lectura, sin escritura); el cliente además usa debounce de 150 ms y cancela la petición anterior (`builder_test.dart`).

## 6. Defectos y observaciones

No se encontró ningún defecto funcional en el código de producción con las pruebas nuevas (las 99 pruebas backend y 5 de Flutter pasaron sin necesitar correcciones en `src/` ni en `lib/`). No se modificó código de producción en esta fase. Todo lo siguiente es de severidad baja o informativa:

| ID    | Severidad | Tipo                  | Descripción                                                                                                                                                                                                                                                                                                              | Esperado / obtenido                                                                                                      | Archivo                                                                                   | Responsable                       |
| ----- | --------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------- | --------------------------------- |
| D-01  | Baja      | Documentación         | Los documentos de la fase 5 afirman que `flutter build windows --debug` falla por falta de ATL y que el criterio 4 queda sin verificar.                                                                                                                                                                                  | Esperado: coherente con el estado real. Obtenido: la compilación ahora funciona (generó `good_pizza.exe` dos veces en esta sesión). | `docs/05-frontend/entregable.md` (§2 punto 8, §5), `pruebas-unitarias.md`, `documentacion-tecnica.md`, `flujo.md` | flutter-dev / mantenimiento       |
| D-02  | Baja      | Documentación         | Conteos de pruebas desactualizados: backend "190 (168 + 22)" y frontend "221".                                                                                                                                                                                                                                            | Ahora backend 289 (267 + 22 omitidas) y frontend 225 + 1 de integración.                                                  | `docs/04-backend/*.md`, `docs/05-frontend/*.md`                                           | mantenimiento (fase 9)            |
| D-03  | Baja      | Seguridad (observación) | `requireAuth` valida el JWT sin consultar la BD: un usuario desactivado conserva acceso de lectura hasta que caduca el access token (15 min); solo `POST /orders` y el login comprueban `active`. El contrato dice "403 usuario desactivado" sin precisar. No hay endpoint para desactivar usuarios.                    | Esperado: decidir si basta con la caducidad de 15 min. Obtenido: comportamiento descrito.                                 | `backend/src/middlewares/requireAuth.js`                                                  | backend-dev / fase 7 (seguridad)  |
| D-04  | Baja      | Robustez (observación) | `calculatePizza` asigna cualquier tarifa distinta de 0 al subtotal 15 % y el IVA se calcula siempre al 15 %; el CHECK de BD admite tarifas de 0 a 100 %. Hoy solo existen 15 % y 0 % (seed, sin endpoint de tarifas), por lo que no afecta.                                                                                | Esperado: alinear si algún día se agregan tarifas. Obtenido: documentado como decisión en `docs/04-backend/entregable.md`. | `backend/src/services/pricing-engine/calculatePizza.js`, migración `add_check_constraints` | backend-dev (sin acción ahora)    |
| D-05  | Media     | Cobertura / entorno   | Las 22 pruebas con BD real se omiten sin `DATABASE_URL_TEST`; criterio de concurrencia (US-11, IT-B03/B04) sin verificar en esta sesión.                                                                                                                                                                                  | Esperado: ejecutadas. Obtenido: omitidas (no se derivó la URL).                                                          | `backend/tests/integration/db.test.js`                                                    | **Usuario** (definir la variable y `npm run db:test:migrate`) |
| D-06  | Baja      | Doc / coherencia      | La matriz de permisos del contrato dice que el ADMIN ve "todos" en `/ingredients` y `/preset-pizzas`, pero el texto exige `includeInactive=true` (PA-B1 de la fase 4).                                                                                                                                                   | Aplicado: por defecto solo activos; el admin envía `includeInactive=true` (decisión por defecto). Sigue en "Preguntas abiertas". | `docs/02-architecture/api-contract.md` §3                                                 | architect                         |

Defectos corregidos por QA: ninguno (no hubo defectos de código). Los cambios hechos en esta fase son solo pruebas, dependencias de desarrollo y `.gitignore`.

Hallazgos de ejecución de pruebas (no son defectos de la app):

- Prueba QA-F01: tras confirmar, la lista "Mis pedidos" del doble no incluía el pedido hasta pulsar "Actualizar" porque el repositorio falso no agrega solo el pedido a `summaries` (hipótesis no comprobada: la lista se carga al navegar al comprobante, antes de que el doble tenga el pedido). Con el backend real el pedido ya existe en ese momento; el refresco manual está documentado en la pantalla. Verificarlo contra el backend real queda pendiente.
- `integration_test`: con la ventana de prueba por defecto (pequeña) las filas del armado quedaban fuera de pantalla y el toque fallaba; se fijó una vista lógica de 1600x1300. Es una restricción del arnés (las listas son perezosas), no de la app (ventana real 1280x800, mínimo recomendado 1024).

## 7. Coherencia entre documentos y código

| Verificación                                                    | Resultado                                                                                                                                                                                      |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Endpoints: contrato vs rutas (`routes/index.js`) vs README      | **Coherente**: 25 = 25 = 25 (6 de salud/autenticación, 3 catálogos, 6 ingredientes, 5 predefinidas, 5 pedidos; sin DELETE ni cancelación, comprobado en pruebas con 404 `ROUTE_NOT_FOUND`)    |
| Códigos de error: contrato §1.2 vs `src/`                       | **Coherente**: el contrato define 24 códigos (la fila `PRESET_CODE_EXISTS`/`PRESET_NAME_EXISTS` cuenta 2) y todos aparecen en `src/` (`FORBIDDEN` vía `forbidden()`); el frontend verifica los 24 (`api_exception_test.dart`) |
| ER vs `schema.prisma`                                           | **Coherente a nivel de entidades**: los 15 modelos de Prisma coinciden con las 15 entidades de `docs/04-backend/diagrama-er.md`; 3 enums; 9 CHECK en la migración. Los ER de fases 1-3 y 5 son conceptuales/parciales (por diseño). `diagrama-er.md` de esta fase se redactó a partir de `schema.prisma` |
| Migraciones: README vs carpeta                                  | Coherente: 3 migraciones (`init`, `init` vacía, `add_check_constraints`)                                                                                                                       |
| Pantallas: `screens.md` (13) vs `lib/features`                   | Coherente: 7 pantallas de cliente y 6 de administrador (+ diálogo de stock)                                                                                                                     |
| Conteos de pruebas en docs 04/05                                | **Incoherente (D-02)**                                                                                                                                                                          |
| Estado de la compilación Windows en docs 05                     | **Incoherente (D-01)**                                                                                                                                                                          |
| Regla de IVA en docs vs código                                  | Coherente (half-up sobre subtotal 15 % del pedido; verificado con 20 001 casos)                                                                                                                 |
| Matriz de permisos (contrato §3) vs comportamiento              | Coherente salvo PA-B1 (D-06)                                                                                                                                                                    |

## 8. Lo que no se pudo verificar

- Concurrencia y SQL real (stock simultáneo, secuencia diaria, CHECK, atomicidad) en esta sesión: pruebas (BD) omitidas por falta de `DATABASE_URL_TEST`.
- Seed ejecutado sobre una base real (tampoco se ejecutó sobre `public`).
- `flutter run -d windows` interactivo y prueba de humo contra el backend real.
- `flutter_secure_storage` real y `dio_provider.dart`.
- Latencia de `/orders/quote` con PostgreSQL real.
- Revisión visual manual (contraste real, fuente Segoe UI) más allá de las pruebas automáticas de contraste y semántica.

## 9. Preguntas abiertas

1. PA-B1 (heredada): ¿el valor por defecto del ADMIN en listados es ver todos o solo activos? Se mantiene "solo activos; el admin envía `includeInactive=true`".
2. D-03: ¿es aceptable que un usuario desactivado mantenga lectura hasta 15 minutos, o se exige comprobar `active` en cada petición?
3. ¿Se autoriza definir `DATABASE_URL_TEST` (esquema `test`) para ejecutar las 22 pruebas de integración y cerrar D-05?
